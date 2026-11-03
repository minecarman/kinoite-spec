{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.ByteString (ByteString)
import Data.Either (isLeft)
import Src.Config (parseConfig)
import Src.System.Flatpak (parseFlatpakList)
import Src.System.Ostree (parseOstreeStatus)
import Src.Types.Spec
  ( FlatpakId (..)
  , PackageName (..)
  , SystemSpec (..)
  , systemFlatpak
  , systemOstree
  , flatpakUser
  , ostreeLayeredPackages
  )
import qualified Data.Set as Set

main :: IO ()
main = do
  assert "valid configuration parses" validConfiguration
  assert "invalid configuration returns an error" invalidConfiguration
  assert "rpm-ostree JSON parses requested packages" ostreeJson
  assert "flatpak JSON separates installations" flatpakJson
  assert "malformed inspection JSON returns an error" malformedJson

validConfiguration :: Bool
validConfiguration =
  case parseConfig validYaml of
    Right specification ->
      systemVersion specification == 1
        && ostreeLayeredPackages (systemOstree specification)
          == Set.fromList [PackageName "zsh", PackageName "git"]
        && flatpakUser (systemFlatpak specification)
          == Set.singleton (FlatpakId "com.spotify.Client")
    Left _ -> False

invalidConfiguration :: Bool
invalidConfiguration = isLeft (parseConfig "version: nope\n")

ostreeJson :: Bool
ostreeJson =
  parseOstreeStatus
    "{\"deployments\":[{\"requested-packages\":[\"zsh\",\"git\"]}]}"
    == Right (Set.fromList [PackageName "zsh", PackageName "git"])

flatpakJson :: Bool
flatpakJson =
  parseFlatpakList
    "[\
    \{\"application_id\":\"org.mozilla.Firefox\",\"installation\":\"system\"},\
    \{\"runtime\":\"org.gnome.Platform\",\"installation\":\"system\"},\
    \{\"application_id\":\"com.spotify.Client\",\"installation\":\"user\"}]"
    == Right
      ( Set.singleton (FlatpakId "com.spotify.Client")
      , Set.singleton (FlatpakId "org.mozilla.Firefox")
      )

malformedJson :: Bool
malformedJson =
  isLeft (parseOstreeStatus "{\"deployments\": [}")
    && isLeft (parseFlatpakList "[{\"application\": false}]")

validYaml :: ByteString
validYaml =
  "version: 1\n\
  \ostree:\n\
  \  layered_packages:\n\
  \    - zsh\n\
  \    - git\n\
  \flatpak:\n\
  \  user:\n\
  \    - com.spotify.Client\n\
  \  system: []\n"

assert :: String -> Bool -> IO ()
assert description condition =
  if condition
    then pure ()
    else fail description
