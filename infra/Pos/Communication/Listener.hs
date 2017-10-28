{-# LANGUAGE Rank2Types #-}

-- | Protocol/versioning related communication helpers.

module Pos.Communication.Listener
       ( listenerConv
       ) where

import qualified Node                            as N
import           System.Wlog                     (WithLogger)
import           Universum

import qualified Network.Broadcast.OutboundQueue as OQ
import           Pos.Binary.Class                (Bi)
import           Pos.Binary.Infra                ()
import           Pos.Communication.Protocol      (ConversationActions, HandlerSpec (..),
                                                  ListenerSpec (..), Message, NodeId,
                                                  OutSpecs, VerInfo (..),
                                                  checkProtocolMagic, checkingInSpecs,
                                                  messageCode)
import           Pos.Network.Types               (Bucket)

-- TODO automatically provide a 'recvLimited' here by using the
-- 'MessageLimited'?
listenerConv
    :: forall snd rcv pack m .
       ( Bi snd
       , Bi rcv
       , Message snd
       , Message rcv
       , WithLogger m
       , MonadIO m
       )
    => OQ.OutboundQ pack NodeId Bucket
    -> (VerInfo -> NodeId -> ConversationActions snd rcv m -> m ())
    -> (ListenerSpec m, OutSpecs)
listenerConv oq h = (lspec, mempty)
  where
    spec = (rcvMsgCode, ConvHandler sndMsgCode)
    lspec =
      flip ListenerSpec spec $ \ourVerInfo ->
          N.Listener $ \peerVerInfo' nNodeId conv -> checkProtocolMagic ourVerInfo peerVerInfo' $ do
              OQ.clearFailureOf oq nNodeId
              checkingInSpecs ourVerInfo peerVerInfo' spec nNodeId $
                  h ourVerInfo nNodeId conv

    sndProxy :: Proxy snd
    sndProxy = Proxy
    rcvProxy :: Proxy rcv
    rcvProxy = Proxy

    sndMsgCode = messageCode sndProxy
    rcvMsgCode = messageCode rcvProxy
