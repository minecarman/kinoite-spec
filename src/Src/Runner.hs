{-# LANGUAGE OverloadedStrings #-}

module Src.Runner
  ( commandForAction
  , runActions
  , runAction
  ) where

import Control.Exception (IOException, try)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text.Encoding
import qualified Data.Set as Set
import Src.Types.Action (Action (..), Scope (..))
import Src.Host (resolveHostCommand)
import Src.Types.Spec
  ( DistroboxSpec (..)
  , DistroboxName (..)
  , FlatpakId (..)
  , FlatpakOverride (..)
  , PackageName (..)
  )
import System.Exit (ExitCode (..))
import System.Process.Typed (proc, readProcess)

runActions :: [Action] -> IO (Either Text ())
runActions [] = pure (Right ())
runActions (action : remaining) = do
  result <- runAction action
  case result of
    Left message -> pure (Left message)
    Right () -> runActions remaining

runAction :: Action -> IO (Either Text ())
runAction action = do
  let (command, arguments) = commandForAction action
  (resolvedCommand, resolvedArguments) <- resolveHostCommand command arguments
  result <- try (readProcess (proc resolvedCommand resolvedArguments))
  pure $ case result of
    Left exception -> Left (commandUnavailable (Text.pack command) exception)
    Right (exitCode, _, errorOutput) ->
      case exitCode of
        ExitSuccess -> Right ()
        ExitFailure _ ->
          Left (commandFailure (Text.pack command) (LazyByteString.toStrict errorOutput))

commandForAction :: Action -> (FilePath, [String])
commandForAction action =
  case action of
    InstallOstree (PackageName packageName) ->
      hostCommand "rpm-ostree" ["install", Text.unpack packageName]
    RemoveOstree (PackageName packageName) ->
      hostCommand "rpm-ostree" ["uninstall", Text.unpack packageName]
    InstallFlatpak (FlatpakId flatpakId) scope remote ->
      hostCommand "flatpak" (scopeArguments scope <> ["install", "--noninteractive"] <> maybe [] (\name -> [Text.unpack name]) remote <> [Text.unpack flatpakId])
    RemoveFlatpak (FlatpakId flatpakId) scope ->
      hostCommand "flatpak" (scopeArguments scope <> ["uninstall", "--noninteractive", Text.unpack flatpakId])
    ApplyFlatpakOverride (FlatpakId flatpakId) scope override ->
      hostCommand
        "flatpak"
        ( scopeArguments scope
            <> ["override"]
            <> map ("--filesystem=" <>) (map Text.unpack (Set.toAscList (overrideFilesystem override)))
            <> map ("--env=" <>) (map Text.unpack (Set.toAscList (overrideEnvironment override)))
            <> map ("--socket=" <>) (map Text.unpack (Set.toAscList (overrideSockets override)))
            <> [Text.unpack flatpakId]
        )
    CreateDistrobox specification ->
      ( "distrobox-host-exec"
      , [ "distrobox"
        , "create"
        , "--name"
        , Text.unpack (distroboxNameText (distroboxName specification))
        , "--image"
        , Text.unpack (distroboxImage specification)
        ]
          <> homeArguments (distroboxHome specification)
      )

hostCommand :: String -> [String] -> (FilePath, [String])
hostCommand command arguments =
  ("distrobox-host-exec", command : arguments)

scopeArguments :: Scope -> [String]
scopeArguments scope =
  case scope of
    User -> ["--user"]
    System -> ["--system"]

homeArguments :: Maybe Text -> [String]
homeArguments maybeHome =
  case maybeHome of
    Nothing -> []
    Just home -> ["--home", Text.unpack home]

distroboxNameText :: DistroboxName -> Text
distroboxNameText (DistroboxName name) = name

commandFailure :: Text -> ByteString -> Text
commandFailure command errorOutput =
  command <> " failed: " <> Text.strip (Text.Encoding.decodeUtf8 errorOutput)

commandUnavailable :: Text -> IOException -> Text
commandUnavailable command exception =
  command <> " could not be started: " <> Text.pack (show exception)
