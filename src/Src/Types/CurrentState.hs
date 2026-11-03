module Src.Types.CurrentState
  ( CurrentState (..)
  ) where

import Data.Set (Set)
import Src.Types.Spec (DistroboxName, FlatpakId, PackageName)

data CurrentState = CurrentState
  { currentOstreePackages :: Set PackageName
  , currentFlatpakUser :: Set FlatpakId
  , currentFlatpakSystem :: Set FlatpakId
  , currentDistroboxes :: Set DistroboxName
  }
  deriving (Eq, Show)
