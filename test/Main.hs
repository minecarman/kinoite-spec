{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.ByteString (ByteString)
import Data.Either (isLeft)
import Src.Config (parseConfig)
import Src.Engine.Diff (diff)
import Src.Runner (commandForAction)
import Src.System.Distrobox (parseDistroboxList, parseDistroboxSpecs)
import Src.System.Flatpak (parseFlatpakList, parseFlatpakOverride)
import Src.System.Ostree (parseOstreeStatus)
import Src.Types.Action (Action (..), Scope (..))
import Src.Types.CurrentState (CurrentState (..))
import Src.Types.Spec
  ( DistroboxName (..)
  , DistroboxSpec (..)
  , FlatpakId (..)
  , FlatpakOverride (..)
  , FlatpakSpec (..)
  , OstreeSpec (..)
  , PackageName (..)
  , SystemSpec (..)
  , systemFlatpak
  , systemOstree
  , flatpakUser
  , flatpakOverrides
  , ostreeLayeredPackages
  )
import Src.UI.Printer (renderAction)
import qualified Data.Set as Set
import qualified Data.Map as Map

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
  assert "distrobox list parses names" distroboxJson
  assert "distrobox export parses image data" distroboxExportJson
  assert "diff creates missing distroboxes" distroboxDiff
  assert "flatpak overrides parse and produce actions" overrideDiff
  assert "flatpak override output parses" overrideOutput

validConfiguration :: Bool
validConfiguration =
  case parseConfig validYaml of
    Right specification ->
      systemVersion specification == 1
        && ostreeLayeredPackages (systemOstree specification)
          == Set.fromList [PackageName "zsh", PackageName "git"]
        && flatpakUser (systemFlatpak specification)
          == Set.singleton (FlatpakId "com.spotify.Client")
        && flatpakOverrides (systemFlatpak specification)
          == Map.singleton
            (FlatpakId "com.spotify.Client")
            (FlatpakOverride (Set.singleton "home") (Set.singleton "EDITOR=vim") (Set.singleton "wayland"))
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
    && commandForAction (CreateDistrobox (DistroboxSpec (DistroboxName "dev-box") "fedora:latest" (Just "~/Dev")))
      == ("distrobox-host-exec", ["distrobox", "create", "--name", "dev-box", "--image", "fedora:latest", "--home", "~/Dev"])
    && commandForAction
      (ApplyFlatpakOverride
        (FlatpakId "com.example.App")
        User
        (FlatpakOverride (Set.singleton "host") (Set.singleton "KEY=value") (Set.singleton "wayland")))
      == ("distrobox-host-exec", ["flatpak", "--user", "override", "--filesystem=host", "--env=KEY=value", "--socket=wayland", "com.example.App"])

overrideDiff :: Bool
overrideDiff =
  diff currentState overrideSpec
    == [ApplyFlatpakOverride (FlatpakId "com.old.App") User
          (FlatpakOverride (Set.singleton "home") Set.empty Set.empty)]

overrideOutput :: Bool
overrideOutput =
  parseFlatpakOverride
    "[Context]\n\
    \sockets=x11;wayland;\n\
    \filesystems=home;\n\
    \[Environment]\n\
    \EDITOR=vim\n"
    == Right (FlatpakOverride (Set.singleton "home") (Set.singleton "EDITOR=vim") (Set.fromList ["wayland", "x11"]))

distroboxJson :: Bool
distroboxJson =
  parseDistroboxList
    "ID           | NAME       | STATUS | IMAGE\n\
    \1            | dev-box    | Up     | fedora:latest\n\
    \2            | media-box  | Exited | fedora:latest\n"
    == Right (Set.fromList [DistroboxName "dev-box", DistroboxName "media-box"])

distroboxExportJson :: Bool
distroboxExportJson =
  parseDistroboxSpecs
    "ID           | NAME       | STATUS | IMAGE\n\
    \1            | dev-box    | Up     | fedora:latest\n"
    == Right
      [DistroboxSpec (DistroboxName "dev-box") "fedora:latest" Nothing]

distroboxDiff :: Bool
distroboxDiff =
  diff currentState targetWithDistrobox
    == [CreateDistrobox (DistroboxSpec (DistroboxName "dev-box") "fedora:latest" (Just "~/Dev"))]

currentState :: CurrentState
currentState =
  CurrentState
    { currentOstreePackages =
        Set.fromList [PackageName "zsh", PackageName "vim"]
    , currentFlatpakUser = Set.singleton (FlatpakId "com.old.App")
    , currentFlatpakSystem = Set.empty
    , currentFlatpakOverrides = mempty
    , currentDistroboxes = Set.empty
    }

targetWithDistrobox :: SystemSpec
targetWithDistrobox =
  SystemSpec
    { systemVersion = 1
    , systemOstree =
        OstreeSpec
          (Set.fromList [PackageName "zsh", PackageName "vim"])
    , systemFlatpak =
        FlatpakSpec
          (Set.singleton (FlatpakId "com.old.App"))
          Set.empty
          mempty
    , systemDistroboxes =
        [DistroboxSpec (DistroboxName "dev-box") "fedora:latest" (Just "~/Dev")]
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
          , flatpakOverrides = mempty
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
          , flatpakOverrides = mempty
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
  <> "  overrides:\n\
  \    com.spotify.Client:\n\
  \      filesystem:\n\
  \        - home\n\
  \      environment:\n\
  \        - EDITOR=vim\n\
  \      sockets:\n\
  \        - wayland\n"

overrideSpec :: SystemSpec
overrideSpec =
  currentSpec
    { systemFlatpak =
        (systemFlatpak currentSpec)
          { flatpakOverrides =
              Map.singleton
                (FlatpakId "com.old.App")
                (FlatpakOverride (Set.singleton "home") Set.empty Set.empty)
          }
    }

assert :: String -> Bool -> IO ()
assert description condition =
  if condition
    then pure ()
    else fail description
