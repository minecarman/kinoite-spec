module Src.Engine.Diff
  ( diff
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Data.Map (Map)
import qualified Data.Map as Map
import Src.Types.Action (Action (..), Scope (..))
import Src.Types.CurrentState
  ( CurrentState (..)
  )
import Src.Types.Spec
  ( DistroboxSpec (..)
  , FlatpakId
  , FlatpakOverride (..)
  , FlatpakSpec (..)
  , OstreeSpec (..)
  , PackageName
  , SystemSpec (..)
  )

diff :: CurrentState -> SystemSpec -> [Action]
diff current target =
  ostreeActions current target
    <> flatpakActions current target
    <> distroboxActions current target

ostreeActions :: CurrentState -> SystemSpec -> [Action]
ostreeActions current target =
  installActions InstallOstree (targetPackages `Set.difference` currentPackages)
    <> removeActions RemoveOstree (currentPackages `Set.difference` targetPackages)
  where
    currentPackages :: Set PackageName
    currentPackages = currentOstreePackages current
    targetPackages :: Set PackageName
    targetPackages = ostreeLayeredPackages (systemOstree target)

flatpakActions :: CurrentState -> SystemSpec -> [Action]
flatpakActions current target =
  flatpakScopeActions
    User
    (currentFlatpakUser current)
    (flatpakUser (systemFlatpak target))
    (flatpakRemotes (systemFlatpak target))
    <> flatpakScopeActions
      System
      (currentFlatpakSystem current)
      (flatpakSystem (systemFlatpak target))
      (flatpakRemotes (systemFlatpak target))
    <> overrideActions current target

overrideActions :: CurrentState -> SystemSpec -> [Action]
overrideActions current target =
  [ ApplyFlatpakOverride flatpakId scope override
  | (flatpakId, override) <- Map.toAscList (flatpakOverrides (systemFlatpak target))
  , not (emptyOverride override)
  , Map.lookup flatpakId (currentFlatpakOverrides current) /= Just override
  , let scope =
          if flatpakId `Set.member` flatpakUser (systemFlatpak target)
            then User
            else System
  ]

emptyOverride :: FlatpakOverride -> Bool
emptyOverride override =
  Set.null (overrideFilesystem override)
    && Set.null (overrideEnvironment override)
    && Set.null (overrideSockets override)

flatpakScopeActions :: Scope -> Set FlatpakId -> Set FlatpakId -> Map FlatpakId Text -> [Action]
flatpakScopeActions scope current target remotes =
  installFlatpaks (target `Set.difference` current)
    <> removeFlatpaks (current `Set.difference` target)
  where
    installFlatpaks :: Set FlatpakId -> [Action]
    installFlatpaks items =
      [InstallFlatpak item scope (Map.lookup item remotes) | item <- Set.toAscList items]
    removeFlatpaks :: Set FlatpakId -> [Action]
    removeFlatpaks items =
      [RemoveFlatpak item scope | item <- Set.toAscList items]

distroboxActions :: CurrentState -> SystemSpec -> [Action]
distroboxActions current target =
  [ CreateDistrobox specification
  | specification <- systemDistroboxes target
  , distroboxName specification `Set.notMember` currentDistroboxes current
  ]

installActions :: (item -> Action) -> Set item -> [Action]
installActions constructor items =
  [constructor item | item <- Set.toAscList items]

removeActions :: (item -> Action) -> Set item -> [Action]
removeActions constructor items =
  [constructor item | item <- Set.toAscList items]
