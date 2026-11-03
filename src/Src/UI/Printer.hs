{-# LANGUAGE OverloadedStrings #-}

module Src.UI.Printer
  ( printPlan
  , renderAction
  ) where

import Data.Text (Text)
import qualified Data.Text.IO as Text.IO
import Src.Types.Action (Action (..), Scope (..))
import System.Console.ANSI
  ( Color (..)
  , ColorIntensity (Vivid)
  , ConsoleLayer (Foreground)
  , ConsoleIntensity (BoldIntensity)
  , SGR (..)
  , setSGR
  )
import Src.Types.Spec
  ( DistroboxName (..)
  , DistroboxSpec (..)
  , FlatpakId (..)
  , PackageName (..)
  )

printPlan :: [Action] -> IO ()
printPlan actions =
  if null actions
    then Text.IO.putStrLn "Sistem senkronize durumda."
    else mapM_ printColoredAction actions

renderAction :: Action -> Text
renderAction action =
  case action of
    InstallOstree (PackageName packageName) ->
      "+ Kurulacak Ostree paketi: " <> packageName
    RemoveOstree (PackageName packageName) ->
      "- Kaldırılacak Ostree paketi: " <> packageName
    InstallFlatpak (FlatpakId flatpakId) scope ->
      "+ Kurulacak Flatpak (" <> renderScope scope <> "): " <> flatpakId
    RemoveFlatpak (FlatpakId flatpakId) scope ->
      "- Kaldırılacak Flatpak (" <> renderScope scope <> "): " <> flatpakId
    ApplyFlatpakOverride (FlatpakId flatpakId) scope _ ->
      "~ Uygulanacak Flatpak override (" <> renderScope scope <> "): " <> flatpakId
    CreateDistrobox specification ->
      "+ Oluşturulacak Distrobox: "
        <> renderDistroboxName (distroboxName specification)

printColoredAction :: Action -> IO ()
printColoredAction action = do
  setSGR [SetConsoleIntensity BoldIntensity, SetColor Foreground Vivid (actionColor action)]
  Text.IO.putStrLn (renderAction action)
  setSGR [Reset]

actionColor :: Action -> Color
actionColor action =
  case action of
    InstallOstree _ -> Green
    InstallFlatpak _ _ -> Green
    RemoveOstree _ -> Red
    RemoveFlatpak _ _ -> Red
    ApplyFlatpakOverride _ _ _ -> Blue
    CreateDistrobox _ -> Green

renderScope :: Scope -> Text
renderScope scope =
  case scope of
    User -> "user"
    System -> "system"

renderDistroboxName :: DistroboxName -> Text
renderDistroboxName (DistroboxName name) = name
