{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Text (Text)
import qualified Data.Text as Text
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
  , (<**>)
  )
import Src.Config (ConfigError, loadConfig)
import Src.Engine.Diff (diff)
import Src.System.Flatpak (inspectFlatpak)
import Src.System.Ostree (inspectOstree)
import Src.Types.CurrentState (CurrentState (..))
import Src.UI.Printer (printPlan)
import System.Exit (exitFailure)

data Command
  = Plan FilePath

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
    (command "plan" (info planParser (progDesc "Sistem farklarını göster")))

planParser :: Parser Command
planParser =
  Plan
    <$> strOption
      ( long "config"
          <> short 'c'
          <> metavar "FILE"
          <> help "Okunacak YAML konfigürasyon dosyası"
      )

runCommand :: Command -> IO ()
runCommand cliCommand =
  case cliCommand of
    Plan path -> runPlan path

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

inspectCurrentState :: IO (Either Text CurrentState)
inspectCurrentState = do
  ostreeResult <- inspectOstree
  flatpakResult <- inspectFlatpak
  pure $ do
    ostreePackages <- ostreeResult
    (flatpakUserPackages, flatpakSystemPackages) <- flatpakResult
    pure
      CurrentState
        { currentOstreePackages = ostreePackages
        , currentFlatpakUser = flatpakUserPackages
        , currentFlatpakSystem = flatpakSystemPackages
        }

renderConfigError :: ConfigError -> Text
renderConfigError configError =
  "Konfigürasyon hatası: " <> Text.pack (show configError)

reportError :: Text -> IO ()
reportError message = do
  Text.IO.putStrLn ("Hata: " <> message)
  exitFailure
