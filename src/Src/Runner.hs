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
import Src.Types.Action (Action (..), Scope (..))
import Src.Types.Spec (FlatpakId (..), PackageName (..))
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
  result <- try (readProcess (proc command arguments))
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
    InstallFlatpak (FlatpakId flatpakId) scope ->
      hostCommand "flatpak" (scopeArguments scope <> ["install", "--noninteractive", Text.unpack flatpakId])
    RemoveFlatpak (FlatpakId flatpakId) scope ->
      hostCommand "flatpak" (scopeArguments scope <> ["uninstall", "--noninteractive", Text.unpack flatpakId])

hostCommand :: String -> [String] -> (FilePath, [String])
hostCommand command arguments =
  ("distrobox-host-exec", command : arguments)

scopeArguments :: Scope -> [String]
scopeArguments scope =
  case scope of
    User -> ["--user"]
    System -> ["--system"]

commandFailure :: Text -> ByteString -> Text
commandFailure command errorOutput =
  command <> " failed: " <> Text.strip (Text.Encoding.decodeUtf8 errorOutput)

commandUnavailable :: Text -> IOException -> Text
commandUnavailable command exception =
  command <> " could not be started: " <> Text.pack (show exception)
