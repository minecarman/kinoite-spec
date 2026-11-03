{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text.Encoding
import qualified Data.Text.IO as Text.IO
import Options.Applicative
  ( Parser
  , ParserInfo
  , command
  , execParser
  , fullDesc
  , header
  , help
  , helper
  , hsubparser
  , info
  , long
  , metavar
  , progDesc
  , short
  , strOption
  , switch
  , (<**>)
  )
import Src.Config (ConfigError, loadConfig)
import Src.Engine.Diff (diff)
import Src.Runner (runActions)
import Src.System.Flatpak (inspectFlatpak)
import Src.System.Distrobox (inspectDistroboxSpecs, inspectDistroboxes)
import Src.System.Ostree (inspectOstree)
import Src.Types.CurrentState (CurrentState (..))
import Src.Types.Spec (FlatpakSpec (..), OstreeSpec (..), SystemSpec (..))
import Src.UI.Printer (printPlan)
import Data.Yaml (encode)
import System.Exit (exitFailure)

data Command
  = Plan FilePath
  | Apply FilePath Bool
  | Export

main :: IO ()
main = execParser cliParser >>= runCommand

cliParser :: ParserInfo Command
cliParser =
  info
    (commandParser <**> helper)
    (fullDesc <> progDesc "Fedora Kinoite sistemini hedef konfigürasyonla karşılaştırır" <> header "kinoite-spec")

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "plan" (info planParser (progDesc "Sistem farklarını göster"))
        <> command "apply" (info applyParser (progDesc "Sistem farklarını uygula"))
        <> command "export" (info (pure Export) (progDesc "Mevcut sistemi YAML olarak dışa aktar"))
    )

planParser :: Parser Command
planParser =
  Plan
    <$> strOption
      ( long "config"
          <> short 'c'
          <> metavar "FILE"
          <> help "Okunacak YAML konfigürasyon dosyası"
      )

applyParser :: Parser Command
applyParser =
  Apply
    <$> strOption
      ( long "config"
          <> short 'c'
          <> metavar "FILE"
          <> help "Okunacak YAML konfigürasyon dosyası"
      )
    <*> switch
      ( long "yes"
          <> short 'y'
          <> help "Onay istemeden değişiklikleri uygula"
      )

runCommand :: Command -> IO ()
runCommand cliCommand =
  case cliCommand of
    Plan path -> runPlan path
    Apply path autoConfirm -> runApply path autoConfirm
    Export -> runExport

runPlan :: FilePath -> IO ()
runPlan path = do
  configResult <- loadConfig path
  case configResult of
    Left configError -> reportError (renderConfigError configError)
    Right specification -> do
      currentStateResult <- inspectCurrentState
      case currentStateResult of
        Left message -> reportError message
        Right currentState -> printPlan (diff currentState specification)

runApply :: FilePath -> Bool -> IO ()
runApply path autoConfirm = do
  configResult <- loadConfig path
  case configResult of
    Left configError -> reportError (renderConfigError configError)
    Right specification -> do
      currentStateResult <- inspectCurrentState
      case currentStateResult of
        Left message -> reportError message
        Right currentState -> do
          let actions = diff currentState specification
          printPlan actions
          if null actions
            then pure ()
            else do
              confirmed <- if autoConfirm then pure True else askConfirmation
              if confirmed
                then do
                  result <- runActions actions
                  case result of
                    Left message -> reportError message
                    Right () -> Text.IO.putStrLn "Değişiklikler başarıyla uygulandı."
                else Text.IO.putStrLn "İşlem iptal edildi."

runExport :: IO ()
runExport = do
  ostreeResult <- inspectOstree
  flatpakResult <- inspectFlatpak
  distroboxResult <- inspectDistroboxSpecs
  case (ostreeResult, flatpakResult, distroboxResult) of
    (Right ostreePackages, Right (userPackages, systemPackages), Right distroboxes) ->
      Text.IO.putStr (Text.Encoding.decodeUtf8 (encode specification))
      where
        specification =
          SystemSpec
            { systemVersion = 1
            , systemOstree = OstreeSpec ostreePackages
            , systemFlatpak = FlatpakSpec userPackages systemPackages
            , systemDistroboxes = distroboxes
            }
    (Left message, _, _) -> reportError message
    (_, Left message, _) -> reportError message
    (_, _, Left message) -> reportError message

askConfirmation :: IO Bool
askConfirmation = do
  Text.IO.putStr "Bu değişiklikler uygulansın mı? [e/H] "
  answer <- Text.toLower <$> Text.IO.getLine
  pure (answer == "e" || answer == "evet" || answer == "y" || answer == "yes")

inspectCurrentState :: IO (Either Text CurrentState)
inspectCurrentState = do
  ostreeResult <- inspectOstree
  flatpakResult <- inspectFlatpak
  distroboxResult <- inspectDistroboxes
  pure $ do
    ostreePackages <- ostreeResult
    (flatpakUserPackages, flatpakSystemPackages) <- flatpakResult
    distroboxes <- distroboxResult
    pure
      CurrentState
        { currentOstreePackages = ostreePackages
        , currentFlatpakUser = flatpakUserPackages
        , currentFlatpakSystem = flatpakSystemPackages
        , currentDistroboxes = distroboxes
        }

renderConfigError :: ConfigError -> Text
renderConfigError configError =
  "Konfigürasyon hatası: " <> Text.pack (show configError)

reportError :: Text -> IO ()
reportError message = do
  Text.IO.putStrLn ("Hata: " <> message)
  exitFailure
