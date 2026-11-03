module Src.Types.CurrentState
  ( CurrentState (..)
  ) where

import Data.Set (Set)
import Src.Types.Spec (FlatpakId, PackageName)

data CurrentState = CurrentState
  { currentOstreePackages :: Set PackageName
  , currentFlatpakUser :: Set FlatpakId
  , currentFlatpakSystem :: Set FlatpakId
  }
  deriving (Eq, Show)
