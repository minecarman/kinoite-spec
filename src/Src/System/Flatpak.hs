{-# LANGUAGE OverloadedStrings #-}

module Src.System.Flatpak
  ( inspectFlatpak
  , inspectFlatpakOverrides
  , parseFlatpakList
  , parseFlatpakOverride
  ) where

import Control.Exception (IOException, try)
import Data.Aeson (FromJSON (..), withObject, (.:), (.:?))
import qualified Data.Aeson as Aeson
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text.Encoding
import System.Exit (ExitCode (..))
import System.Process.Typed (proc, readProcess)
import Src.Host (resolveHostCommand)
import Src.Types.Spec
  ( FlatpakId (..)
  , FlatpakOverride (..)
  )

data Scope = User | System
data OverrideSection = ContextSection | EnvironmentSection
  deriving (Eq)

data FlatpakEntry = FlatpakEntry
  { flatpakApplication :: Maybe FlatpakId
  , flatpakInstallation :: Text
  }

instance FromJSON FlatpakEntry where
  parseJSON = withObject "flatpak entry" $ \object ->
    FlatpakEntry <$> object .:? "application_id" <*> object .: "installation"

parseFlatpakList :: ByteString -> Either Text (Set FlatpakId, Set FlatpakId)
parseFlatpakList contents = do
  entries <- decodeJson "flatpak list" contents
  pure
    ( Set.fromList
        [ application
        | entry <- entries
        , Just application <- [flatpakApplication entry]
        , flatpakInstallation entry == "user"
        ]
    , Set.fromList
        [ application
        | entry <- entries
        , Just application <- [flatpakApplication entry]
        , flatpakInstallation entry == "system"
        ]
    )

inspectFlatpak :: IO (Either Text (Set FlatpakId, Set FlatpakId))
inspectFlatpak = do
  (command, arguments) <- resolveHostCommand "flatpak" ["list", "--json"]
  result <-
    try
      (readProcess (proc command arguments))
      :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
  pure $ case result of
    Left exception -> Left (commandUnavailable "distrobox-host-exec flatpak" exception)
    Right (exitCode, output, errorOutput) ->
      case exitCode of
        ExitSuccess -> parseFlatpakList (LazyByteString.toStrict output)
        ExitFailure _ ->
          Left (commandFailure "flatpak" (LazyByteString.toStrict errorOutput))

inspectFlatpakOverrides :: Set FlatpakId -> Set FlatpakId -> IO (Either Text (Map FlatpakId FlatpakOverride))
inspectFlatpakOverrides userApplications systemApplications = do
  userOverrides <- inspectScope User userApplications
  systemOverrides <- inspectScope System systemApplications
  pure $ Map.union <$> userOverrides <*> systemOverrides
  where
    inspectScope :: Scope -> Set FlatpakId -> IO (Either Text (Map FlatpakId FlatpakOverride))
    inspectScope scope applications =
      foldOverrides <$> traverse (inspectOne scope) (Set.toAscList applications)

    inspectOne :: Scope -> FlatpakId -> IO (Either Text (FlatpakId, FlatpakOverride))
    inspectOne scope application = do
      (command, arguments) <-
        resolveHostCommand "flatpak" (scopeArguments scope <> ["override", "--show", flatpakIdText application])
      result <-
        try
          (readProcess (proc command arguments))
        :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
      pure $ case result of
        Left exception -> Left (commandUnavailable "distrobox-host-exec flatpak" exception)
        Right (exitCode, output, errorOutput) ->
          case exitCode of
            ExitSuccess -> do
              override <- parseFlatpakOverride (LazyByteString.toStrict output)
              pure (application, override)
            ExitFailure _ ->
              Left (commandFailure "flatpak override --show" (LazyByteString.toStrict errorOutput))

    foldOverrides :: [Either Text (FlatpakId, FlatpakOverride)] -> Either Text (Map FlatpakId FlatpakOverride)
    foldOverrides results =
      Map.fromList
        <$> sequence
          [ result
          | result <- results
          , keepOverride result
          ]

    keepOverride :: Either Text (FlatpakId, FlatpakOverride) -> Bool
    keepOverride result =
      case result of
        Left _ -> True
        Right (_, override) -> not (emptyOverrideValue override)

scopeArguments :: Scope -> [String]
scopeArguments scope =
  case scope of
    User -> ["--user"]
    System -> ["--system"]

parseFlatpakOverride :: ByteString -> Either Text FlatpakOverride
parseFlatpakOverride contents = do
  text <- case Text.Encoding.decodeUtf8' contents of
    Left exception -> Left ("flatpak override output is not UTF-8: " <> Text.pack (show exception))
    Right value -> Right value
  pure (snd (foldl parseLine (ContextSection, emptyOverride) (Text.lines text)))
  where
    parseLine :: (OverrideSection, FlatpakOverride) -> Text -> (OverrideSection, FlatpakOverride)
    parseLine (section, current) rawLine =
      let line = Text.strip rawLine
       in if line == "[Environment]"
            then (EnvironmentSection, current)
            else if isSection line
              then (ContextSection, current)
            else
              case Text.breakOn "=" line of
                (key, value)
                  | Text.null value -> (section, current)
                  | section == EnvironmentSection ->
                      (section, current {overrideEnvironment = Set.insert line (overrideEnvironment current)})
                  | key == "filesystems" -> (section, current {overrideFilesystem = parseList value})
                  | key == "sockets" -> (section, current {overrideSockets = parseList value})
                  | key == "environment" -> (section, current {overrideEnvironment = parseList value})
                  | otherwise -> (section, current)

    parseList :: Text -> Set Text
    parseList value =
      Set.fromList
        [ Text.strip item
        | item <- Text.splitOn ";" (Text.drop 1 value)
        , not (Text.null (Text.strip item))
        ]

emptyOverride :: FlatpakOverride
emptyOverride = FlatpakOverride mempty mempty mempty

emptyOverrideValue :: FlatpakOverride -> Bool
emptyOverrideValue override =
  Set.null (overrideFilesystem override)
    && Set.null (overrideEnvironment override)
    && Set.null (overrideSockets override)

isSection :: Text -> Bool
isSection line =
  Text.isPrefixOf "[" line && Text.isSuffixOf "]" line

flatpakIdText :: FlatpakId -> String
flatpakIdText (FlatpakId flatpakId) = Text.unpack flatpakId

decodeJson :: Aeson.FromJSON value => Text -> ByteString -> Either Text value
decodeJson label contents =
  case Aeson.eitherDecodeStrict' contents of
    Left message -> Left (label <> " JSON parse error: " <> Text.pack message)
    Right value -> Right value

commandFailure :: Text -> ByteString -> Text
commandFailure command errorOutput =
  command <> " failed: " <> Text.strip (Text.Encoding.decodeUtf8 errorOutput)

commandUnavailable :: Text -> IOException -> Text
commandUnavailable command exception =
  command <> " could not be started: " <> Text.pack (show exception)
