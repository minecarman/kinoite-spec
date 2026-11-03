{-# LANGUAGE OverloadedStrings #-}

module Src.System.Distrobox
  ( inspectDistroboxSpecs
  , inspectDistroboxes
  , parseDistroboxSpecs
  , parseDistroboxList
  ) where

import Control.Exception (IOException, try)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text.Encoding
import Data.Maybe (mapMaybe)
import Src.Types.Spec (DistroboxName (..), DistroboxSpec (..))
import System.Exit (ExitCode (..))
import System.Process.Typed (proc, readProcess)
import Src.Host (resolveHostCommand)

parseDistroboxList :: ByteString -> Either Text (Set DistroboxName)
parseDistroboxList contents =
  Right
    (Set.fromList (map distroboxName (parseDistroboxSpecsUnsafe contents)))

parseDistroboxSpecs :: ByteString -> Either Text [DistroboxSpec]
parseDistroboxSpecs contents =
  Right (parseDistroboxSpecsUnsafe contents)

parseDistroboxSpecsUnsafe :: ByteString -> [DistroboxSpec]
parseDistroboxSpecsUnsafe contents =
  mapMaybe parseDistroboxLine (Text.lines (Text.Encoding.decodeUtf8 contents))

inspectDistroboxes :: IO (Either Text (Set DistroboxName))
inspectDistroboxes = do
  (command, arguments) <- resolveHostCommand "distrobox" ["list", "--no-color"]
  result <-
    try
      (readProcess (proc command arguments))
      :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
  pure $ case result of
    Left exception -> Left (commandUnavailable "distrobox-host-exec distrobox" exception)
    Right (exitCode, output, errorOutput) ->
      case exitCode of
        ExitSuccess -> parseDistroboxList (LazyByteString.toStrict output)
        ExitFailure _ ->
          Left (commandFailure "distrobox" (LazyByteString.toStrict errorOutput))

inspectDistroboxSpecs :: IO (Either Text [DistroboxSpec])
inspectDistroboxSpecs = do
  (command, arguments) <- resolveHostCommand "distrobox" ["list", "--no-color"]
  result <-
    try
      (readProcess (proc command arguments))
      :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
  pure $ case result of
    Left exception -> Left (commandUnavailable "distrobox-host-exec distrobox" exception)
    Right (exitCode, output, errorOutput) ->
      case exitCode of
        ExitSuccess -> parseDistroboxSpecs (LazyByteString.toStrict output)
        ExitFailure _ ->
          Left (commandFailure "distrobox" (LazyByteString.toStrict errorOutput))

commandFailure :: Text -> ByteString -> Text
commandFailure command errorOutput =
  command <> " failed: " <> Text.strip (Text.Encoding.decodeUtf8 errorOutput)

commandUnavailable :: Text -> IOException -> Text
commandUnavailable command exception =
  command <> " could not be started: " <> Text.pack (show exception)

parseDistroboxLine :: Text -> Maybe DistroboxSpec
parseDistroboxLine line =
  case tableFields line of
    Just fields -> parseTableSpec fields
    Nothing -> parseWordsSpec (Text.words line)

tableFields :: Text -> Maybe [Text]
tableFields line =
  case Text.splitOn "|" line of
    [_] -> Nothing
    fields -> Just (map Text.strip fields)

parseTableSpec :: [Text] -> Maybe DistroboxSpec
parseTableSpec fields =
  case fields of
    _ : name : _ : image : _ -> makeSpec name image
    _ -> Nothing

parseWordsSpec :: [Text] -> Maybe DistroboxSpec
parseWordsSpec fields =
  case fields of
    _ : name : _ : image : _ -> makeSpec name image
    _ -> Nothing

makeSpec :: Text -> Text -> Maybe DistroboxSpec
makeSpec name image =
  case parseNameField (Just name) of
    Just distroboxName -> Just (DistroboxSpec distroboxName image Nothing)
    Nothing -> Nothing

parseNameField :: Maybe Text -> Maybe DistroboxName
parseNameField maybeName =
  case maybeName of
    Just name
      | not (Text.null name)
          && Text.toLower name /= "name"
          && not (Text.all (== '-') name) ->
          Just (DistroboxName name)
    _ -> Nothing
