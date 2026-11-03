{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Src.Types.Spec
  ( DistroboxSpec (..)
  , DistroboxName (..)
  , FlatpakId (..)
  , FlatpakSpec (..)
  , OstreeSpec (..)
  , PackageName (..)
  , SystemSpec (..)
  ) where

import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Set (Set)
import Data.Text (Text)
import GHC.Generics (Generic)

newtype PackageName = PackageName Text
  deriving (Eq, Ord, Show, Generic)

newtype FlatpakId = FlatpakId Text
  deriving (Eq, Ord, Show, Generic)

newtype DistroboxName = DistroboxName Text
  deriving (Eq, Ord, Show, Generic)

data OstreeSpec = OstreeSpec
  { ostreeLayeredPackages :: Set PackageName
  }
  deriving (Eq, Show, Generic)

data FlatpakSpec = FlatpakSpec
  { flatpakUser :: Set FlatpakId
  , flatpakSystem :: Set FlatpakId
  }
  deriving (Eq, Show, Generic)

data DistroboxSpec = DistroboxSpec
  { distroboxName :: DistroboxName
  , distroboxImage :: Text
  , distroboxHome :: Maybe Text
  }
  deriving (Eq, Ord, Show, Generic)

data SystemSpec = SystemSpec
  { systemVersion :: Int
  , systemOstree :: OstreeSpec
  , systemFlatpak :: FlatpakSpec
  , systemDistroboxes :: [DistroboxSpec]
  }
  deriving (Eq, Show, Generic)

instance FromJSON SystemSpec where
  parseJSON = withObject "SystemSpec" $ \object ->
    SystemSpec
      <$> object .: "version"
      <*> object .: "ostree"
      <*> object .: "flatpak"
      <*> object .:? "distrobox" .!= []

instance FromJSON OstreeSpec where
  parseJSON = withObject "OstreeSpec" $ \object ->
    OstreeSpec <$> object .: "layered_packages"

instance FromJSON FlatpakSpec where
  parseJSON = withObject "FlatpakSpec" $ \object ->
    FlatpakSpec
      <$> object .:? "user" .!= mempty
      <*> object .:? "system" .!= mempty

instance FromJSON DistroboxSpec where
  parseJSON = withObject "DistroboxSpec" $ \object ->
    DistroboxSpec
      <$> (DistroboxName <$> object .: "name")
      <*> object .: "image"
      <*> object .:? "home"

instance FromJSON PackageName where
  parseJSON value = PackageName <$> parseJSON value

instance FromJSON FlatpakId where
  parseJSON value = FlatpakId <$> parseJSON value

instance ToJSON PackageName where
  toJSON (PackageName name) = toJSON name

instance ToJSON FlatpakId where
  toJSON (FlatpakId flatpakId) = toJSON flatpakId

instance ToJSON DistroboxName where
  toJSON (DistroboxName name) = toJSON name

instance ToJSON OstreeSpec where
  toJSON specification =
    object ["layered_packages" .= ostreeLayeredPackages specification]

instance ToJSON FlatpakSpec where
  toJSON specification =
    object
      [ "user" .= flatpakUser specification
      , "system" .= flatpakSystem specification
      ]

instance ToJSON DistroboxSpec where
  toJSON specification =
    object
      ( [ "name" .= distroboxName specification
        , "image" .= distroboxImage specification
        ]
          <> maybe [] (\home -> ["home" .= home]) (distroboxHome specification)
      )

instance ToJSON SystemSpec where
  toJSON specification =
    object
      [ "version" .= systemVersion specification
      , "ostree" .= systemOstree specification
      , "flatpak" .= systemFlatpak specification
      , "distrobox" .= systemDistroboxes specification
      ]
