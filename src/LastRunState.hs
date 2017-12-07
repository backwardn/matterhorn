{-# LANGUAGE TemplateHaskell #-}
module LastRunState
  ( LastRunState
  , lrsHost
  , lrsPort
  , lrsUserId
  , lrsSelectedChannelId
  , writeLastRunState
  , readLastRunState
  , isValidLastRunState
  ) where

import Prelude ()
import Prelude.Compat

import Control.Monad.Trans.Except
import Lens.Micro.Platform
import System.Directory (createDirectoryIfMissing)
import System.FilePath (dropFileName)
import qualified System.IO.Strict as S
import qualified System.Posix.Files as P
import qualified System.Posix.Types as P

import IOUtil
import FilePaths
import Network.Mattermost (Hostname, Port)
import Network.Mattermost.Types
import Network.Mattermost.Lenses
import Types
import Zipper (focusL)

-- | Run state of the program. This is saved in a file on program exit and
-- | looked up from the file on program startup.
data LastRunState = LastRunState
  { _lrsHost              :: Hostname  -- ^ Host of the server
  , _lrsPort              :: Port      -- ^ Post of the server
  , _lrsUserId            :: UserId    -- ^ ID of the logged-in user
  , _lrsSelectedChannelId :: ChannelId -- ^ ID of the last selected channel
  } deriving (Show, Read)

makeLenses ''LastRunState

toLastRunState :: ChatState -> LastRunState
toLastRunState cs = LastRunState
  { _lrsHost              = cs^.csResources.crConn.cdHostnameL
  , _lrsPort              = cs^.csResources.crConn.cdPortL
  , _lrsUserId            = cs^.csMe.userIdL
  , _lrsSelectedChannelId = cs^.csFocus.focusL
  }

lastRunStateFileMode :: P.FileMode
lastRunStateFileMode = P.unionFileModes P.ownerReadMode P.ownerWriteMode

-- | Writes the run state to a file. The file is specific to the current team.
writeLastRunState :: ChatState -> IO (Either String ())
writeLastRunState cs = runExceptT . convertIOException $ do
  let runState = toLastRunState cs
      tId      = cs^.csMyTeam.teamIdL
  lastRunStateFile <- lastRunStateFilePath . unId . toId $ tId
  createDirectoryIfMissing True $ dropFileName lastRunStateFile
  writeFile lastRunStateFile $ show runState
  P.setFileMode lastRunStateFile lastRunStateFileMode

-- | Reads the last run state from a file given the current team ID.
readLastRunState :: TeamId -> IO (Either String LastRunState)
readLastRunState tId = runExceptT $ do
  contents <- convertIOException $
    (lastRunStateFilePath . unId . toId $ tId) >>= S.readFile
  case reads contents of
    [(val, "")] -> return val
    _ -> throwE "Failed to parse runState file"

-- | Checks if the given last run state is valid for the current server and user.
isValidLastRunState :: ChatResources -> User -> LastRunState -> Bool
isValidLastRunState cr myUser rs =
     rs^.lrsHost   == cr^.crConn.cdHostnameL
  && rs^.lrsPort   == cr^.crConn.cdPortL
  && rs^.lrsUserId == myUser^.userIdL
