{-# LANGUAGE OverloadedStrings #-}

module Src.System.Flatpak
  ( inspectFlatpak
  , parseFlatpakList
  ) where

import Control.Exception (IOException, try)
import Data.Aeson (FromJSON (..), withObject, (.:), (.:?))
import qualified Data.Aeson as Aeson
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text.Encoding
import System.Exit (ExitCode (..))
import System.Process.Typed (proc, readProcess)
import Src.Types.Spec (FlatpakId (..))

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
  result <-
    try
      (readProcess
        (proc "distrobox-host-exec" ["flatpak", "list", "--json"]))
      :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
  pure $ case result of
    Left exception -> Left (commandUnavailable "distrobox-host-exec flatpak" exception)
    Right (exitCode, output, errorOutput) ->
      case exitCode of
        ExitSuccess -> parseFlatpakList (LazyByteString.toStrict output)
        ExitFailure _ ->
          Left (commandFailure "flatpak" (LazyByteString.toStrict errorOutput))

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
