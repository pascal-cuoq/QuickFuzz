{-# LANGUAGE TemplateHaskell, FlexibleInstances, IncoherentInstances#-}
module Ogg where

import DeriveArbitrary hiding (derive)
import Test.QuickCheck

import Codec.Container.Ogg.Page
import Codec.Container.Ogg.Packet
import Codec.Container.Ogg.Granulepos
import Codec.Container.Ogg.Track
import Codec.Container.Ogg.MessageHeaders
import Codec.Container.Ogg.Granulerate
import Codec.Container.Ogg.ContentType

import qualified Data.ByteString.Lazy as L

--import Data.DeriveTH

import ByteString


instance Arbitrary ContentType where
--    arbitrary = oneof $ (map return [flac])
      arbitrary = oneof $ (map return [skeleton, cmml, vorbis, theora, speex, celt, flac])

instance Arbitrary MessageHeaders where
   arbitrary = do
     y <- listOf (arbitrary :: Gen String)
     x <- (arbitrary :: (Gen String))
     return $ mhAppends x y mhEmpty

$(devArbitrary ''OggPacket)

type MOgg = [OggPacket]

appendvorbis d = L.append flacIdent d
appendh (OggPage x track cont incplt bos eos gp seqno s) = OggPage x track cont incplt bos eos gp seqno (map appendvorbis s)

mencode = L.concat . (map pageWrite) . (map appendh) . packetsToPages --appendvorbis
