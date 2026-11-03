{-# LANGUAGE OverloadedStrings #-}

module Src.System.Ostree
  ( inspectOstree
  , parseOstreeStatus
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
import Src.Types.Spec (PackageName (..))

data OstreeStatus = OstreeStatus
  { ostreeDeployments :: [OstreeDeployment]
  }

data OstreeDeployment = OstreeDeployment
  { ostreeRequestedPackages :: Set PackageName
  }

instance FromJSON OstreeStatus where
  parseJSON = withObject "rpm-ostree status" $ \object ->
    OstreeStatus <$> object .: "deployments"

instance FromJSON OstreeDeployment where
  parseJSON = withObject "rpm-ostree deployment" $ \object ->
    OstreeDeployment <$> (object .:? "requested-packages" Aeson..!= Set.empty)

parseOstreeStatus :: ByteString -> Either Text (Set PackageName)
parseOstreeStatus contents = do
  status <- decodeJson "rpm-ostree status" contents
  case ostreeDeployments status of
    [] -> Left "rpm-ostree status did not contain a deployment"
    deployment : _ -> Right (ostreeRequestedPackages deployment)

inspectOstree :: IO (Either Text (Set PackageName))
inspectOstree = do
  result <-
    try
      (readProcess
        (proc "distrobox-host-exec" ["rpm-ostree", "status", "--json"]))
      :: IO (Either IOException (ExitCode, LazyByteString.ByteString, LazyByteString.ByteString))
  pure $ case result of
    Left exception -> Left (commandUnavailable "distrobox-host-exec rpm-ostree" exception)
    Right (exitCode, output, errorOutput) ->
      case exitCode of
        ExitSuccess -> parseOstreeStatus (LazyByteString.toStrict output)
        ExitFailure _ ->
          Left (commandFailure "rpm-ostree" (LazyByteString.toStrict errorOutput))

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
