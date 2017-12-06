module Draw.Util where

import Prelude ()
import Prelude.Compat

import Brick
import qualified Data.Text as T
import Data.Time.Clock (UTCTime(..))
import Data.Time.Format (formatTime, defaultTimeLocale)
import Data.Time.LocalTime (TimeZone, utcToLocalTime)
import Lens.Micro.Platform
import Network.Mattermost

import Types
import Types.Channels
import Types.Users
import Themes

defaultTimeFormat :: T.Text
defaultTimeFormat = "%R"

defaultDateFormat :: T.Text
defaultDateFormat = "%Y-%m-%d"

getTimeFormat :: ChatState -> T.Text
getTimeFormat st =
    maybe defaultTimeFormat id (st^.csResources.crConfiguration.to configTimeFormat)

getDateFormat :: ChatState -> T.Text
getDateFormat st =
    maybe defaultDateFormat id (st^.csResources.crConfiguration.to configDateFormat)

renderTime :: ChatState -> UTCTime -> Widget Name
renderTime st = renderUTCTime (getTimeFormat st) (st^.timeZone)

renderDate :: ChatState -> UTCTime -> Widget Name
renderDate st = renderUTCTime (getDateFormat st) (st^.timeZone)

renderUTCTime :: T.Text -> TimeZone -> UTCTime -> Widget a
renderUTCTime fmt tz t =
    let timeStr = T.pack $ formatTime defaultTimeLocale (T.unpack fmt) (utcToLocalTime tz t)
    in if T.null fmt
       then emptyWidget
       else withDefAttr timeAttr (txt timeStr)

withBrackets :: Widget a -> Widget a
withBrackets w = hBox [str "[", w, str "]"]

userSigilFromInfo :: UserInfo -> Char
userSigilFromInfo u = case u^.uiStatus of
    Offline      -> ' '
    Online       -> '+'
    Away         -> '-'
    DoNotDisturb -> '×'
    Other _      -> '?'

mkChannelName :: ChannelInfo -> T.Text
mkChannelName c = T.append sigil (c^.cdName)
  where sigil =  case c^.cdType of
          Private   -> T.singleton '?'
          Ordinary  -> normalChannelSigil
          Group     -> normalChannelSigil
          Direct    -> userSigil
          _         -> T.singleton '!'

mkDMChannelName :: UserInfo -> T.Text
mkDMChannelName u = T.cons (userSigilFromInfo u) (u^.uiName)
