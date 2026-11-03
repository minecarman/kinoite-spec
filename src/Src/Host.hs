module Src.Host
  ( resolveHostCommand
  ) where

import System.Directory (findExecutable)

resolveHostCommand :: FilePath -> [String] -> IO (FilePath, [String])
resolveHostCommand command arguments = do
  hostExecutor <- findExecutable "distrobox-host-exec"
  pure
    ( case hostExecutor of
        Just executable -> executable
        Nothing -> command
    , case hostExecutor of
        Just _ -> command : arguments
        Nothing -> arguments
    )
