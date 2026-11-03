module Src.Types.CurrentState
  ( CurrentState (..)
  ) where

import Data.Set (Set)
import Data.Map (Map)
import Data.Text (Text)
import Src.Types.Spec (DistroboxName, FlatpakId, FlatpakOverride, PackageName)

data CurrentState = CurrentState
  { currentOstreePackages :: Set PackageName
  , currentFlatpakUser :: Set FlatpakId
  , currentFlatpakSystem :: Set FlatpakId
  , currentFlatpakRemotes :: Map FlatpakId Text
  , currentFlatpakOverrides :: Map FlatpakId FlatpakOverride
  , currentDistroboxes :: Set DistroboxName
  }
  deriving (Eq, Show)
