module Src.Host
  ( resolveHostCommand
  ) where

import System.Directory (doesFileExist, findExecutable)

resolveHostCommand :: FilePath -> [String] -> IO (FilePath, [String])
resolveHostCommand command arguments = do
  hostExecutor <- findExecutable "distrobox-host-exec"
  inContainer <- doesFileExist "/run/.containerenv"
  pure
    ( if command == "distrobox-host-exec"
        then
          if inContainer
            then command
            else headOr command arguments
        else case (inContainer, hostExecutor) of
          (True, Just executable) -> executable
          _ -> command
    , if command == "distrobox-host-exec"
        then
          if inContainer
            then arguments
            else tailOr arguments
        else case (inContainer, hostExecutor) of
          (True, Just _) -> command : arguments
          _ -> arguments
    )

headOr :: a -> [a] -> a
headOr fallback values =
  case values of
    [] -> fallback
    value : _ -> value

tailOr :: [a] -> [a]
tailOr values =
  case values of
    [] -> []
    _ : remaining -> remaining
