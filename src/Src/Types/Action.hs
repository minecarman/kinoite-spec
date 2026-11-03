module Src.Types.Action
  ( Action (..)
  , Scope (..)
  ) where

import Src.Types.Spec (FlatpakId, PackageName)

data Scope
  = User
  | System
  deriving (Eq, Ord, Show)

data Action
  = InstallOstree PackageName
  | RemoveOstree PackageName
  | InstallFlatpak FlatpakId Scope
  | RemoveFlatpak FlatpakId Scope
  deriving (Eq, Ord, Show)
