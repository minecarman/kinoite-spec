{-# LANGUAGE OverloadedStrings #-}

module Src.Config
  ( ConfigError (..)
  , loadConfig
  , parseConfig
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Control.Exception (IOException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Yaml (ParseException, decodeEither')
import Src.Types.Spec (SystemSpec)

data ConfigError
  = ConfigReadError FilePath Text
  | ConfigParseError ParseException
  deriving (Show)

loadConfig :: FilePath -> IO (Either ConfigError SystemSpec)
loadConfig path = do
  result <- readConfigFile path
  pure $ case result of
    Left message -> Left (ConfigReadError path message)
    Right contents -> parseConfig contents

parseConfig :: ByteString -> Either ConfigError SystemSpec
parseConfig contents =
  case decodeEither' contents of
    Left parseException -> Left (ConfigParseError parseException)
    Right specification -> Right specification

readConfigFile :: FilePath -> IO (Either Text ByteString)
readConfigFile path = do
  result <- readFileSafely path
  pure $ case result of
    Left message -> Left (Text.pack (show message))
    Right contents -> Right contents

readFileSafely :: FilePath -> IO (Either IOException ByteString)
readFileSafely path = do
  result <- tryIOError (ByteString.readFile path)
  pure result

tryIOError :: IO value -> IO (Either IOException value)
tryIOError action = do
  result <- try action
  pure result
