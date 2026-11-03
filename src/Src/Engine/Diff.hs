module Src.Engine.Diff
  ( diff
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Src.Types.Action (Action (..), Scope (..))
import Src.Types.CurrentState
  ( CurrentState (..)
  )
import Src.Types.Spec
  ( FlatpakId
  , FlatpakSpec (..)
  , OstreeSpec (..)
  , PackageName
  , SystemSpec (..)
  )

diff :: CurrentState -> SystemSpec -> [Action]
diff current target =
  ostreeActions current target
    <> flatpakActions current target

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
    <> flatpakScopeActions
      System
      (currentFlatpakSystem current)
      (flatpakSystem (systemFlatpak target))

flatpakScopeActions :: Scope -> Set FlatpakId -> Set FlatpakId -> [Action]
flatpakScopeActions scope current target =
  installFlatpaks (target `Set.difference` current)
    <> removeFlatpaks (current `Set.difference` target)
  where
    installFlatpaks :: Set FlatpakId -> [Action]
    installFlatpaks items =
      [InstallFlatpak item scope | item <- Set.toAscList items]
    removeFlatpaks :: Set FlatpakId -> [Action]
    removeFlatpaks items =
      [RemoveFlatpak item scope | item <- Set.toAscList items]

installActions :: (item -> Action) -> Set item -> [Action]
installActions constructor items =
  [constructor item | item <- Set.toAscList items]

removeActions :: (item -> Action) -> Set item -> [Action]
removeActions constructor items =
  [constructor item | item <- Set.toAscList items]
