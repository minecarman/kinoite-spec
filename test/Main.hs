{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.ByteString (ByteString)
import Data.Either (isLeft)
import Src.Config (parseConfig)
import Src.Engine.Diff (diff)
import Src.Runner (commandForAction)
import Src.System.Flatpak (parseFlatpakList)
import Src.System.Ostree (parseOstreeStatus)
import Src.Types.Action (Action (..), Scope (..))
import Src.Types.CurrentState (CurrentState (..))
import Src.Types.Spec
  ( FlatpakId (..)
  , FlatpakSpec (..)
  , OstreeSpec (..)
  , PackageName (..)
  , SystemSpec (..)
  , systemFlatpak
  , systemOstree
  , flatpakUser
  , ostreeLayeredPackages
  )
import Src.UI.Printer (renderAction)
import qualified Data.Set as Set

main :: IO ()
main = do
  assert "valid configuration parses" validConfiguration
  assert "invalid configuration returns an error" invalidConfiguration
  assert "rpm-ostree JSON parses requested packages" ostreeJson
  assert "flatpak JSON separates installations" flatpakJson
  assert "malformed inspection JSON returns an error" malformedJson
  assert "diff produces install and remove actions" diffActions
  assert "diff ignores resources already in sync" emptyDiff
  assert "printer renders actions" printerOutput
  assert "runner builds safe host commands" runnerCommands

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

diffActions :: Bool
diffActions =
  diff currentState targetSpec
    == [ InstallOstree (PackageName "tmux")
       , RemoveOstree (PackageName "vim")
       , RemoveFlatpak (FlatpakId "com.old.App") User
       , InstallFlatpak (FlatpakId "org.mozilla.Firefox") System
       ]

emptyDiff :: Bool
emptyDiff = diff currentState currentSpec == []

printerOutput :: Bool
printerOutput =
  renderAction (InstallOstree (PackageName "zsh"))
    == "+ Kurulacak Ostree paketi: zsh"
    && renderAction (RemoveFlatpak (FlatpakId "com.example.App") User)
      == "- Kaldırılacak Flatpak (user): com.example.App"

runnerCommands :: Bool
runnerCommands =
  commandForAction (InstallOstree (PackageName "zsh"))
    == ("distrobox-host-exec", ["rpm-ostree", "install", "zsh"])
    && commandForAction (RemoveFlatpak (FlatpakId "com.example.App") User)
      == ("distrobox-host-exec", ["flatpak", "--user", "uninstall", "--noninteractive", "com.example.App"])

currentState :: CurrentState
currentState =
  CurrentState
    { currentOstreePackages =
        Set.fromList [PackageName "zsh", PackageName "vim"]
    , currentFlatpakUser = Set.singleton (FlatpakId "com.old.App")
    , currentFlatpakSystem = Set.empty
    }

targetSpec :: SystemSpec
targetSpec =
  SystemSpec
    { systemVersion = 1
    , systemOstree =
        OstreeSpec
          { ostreeLayeredPackages =
              Set.fromList [PackageName "zsh", PackageName "tmux"]
          }
    , systemFlatpak =
        FlatpakSpec
          { flatpakUser = Set.empty
          , flatpakSystem = Set.fromList [FlatpakId "org.mozilla.Firefox"]
          }
    , systemDistroboxes = []
    }

currentSpec :: SystemSpec
currentSpec =
  SystemSpec
    { systemVersion = 1
    , systemOstree =
        OstreeSpec
          { ostreeLayeredPackages =
              Set.fromList [PackageName "zsh", PackageName "vim"]
          }
    , systemFlatpak =
        FlatpakSpec
          { flatpakUser = Set.singleton (FlatpakId "com.old.App")
          , flatpakSystem = Set.empty
          }
    , systemDistroboxes = []
    }

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
