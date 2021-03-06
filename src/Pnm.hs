{-# LANGUAGE TemplateHaskell, FlexibleInstances#-}

module Pnm where

import Test.QuickCheck

import qualified Codec.PPM.Binary as BPPM
import qualified Codec.PPM.Text as TPPM

--import Data.Binary( Binary(..), encode )
import Data.Word(Word8, Word16, Word32)

import qualified Data.ByteString.Lazy as L
import DeriveArbitrary

import Data.List.Split

data MPnmType  = BinaryPnm | TextPnm

instance Show MPnmType where
   show BinaryPnm = "BPPM"
   show TextPnm = "TPPM"

type MPnmImage  = (MPnmType,Integer,Integer, [(Word8,Word8,Word8)])
$(deriveArbitrary ''MPnmType)

encodePnmImage (BinaryPnm, x, y, d) = BPPM.stringPPM (x,y) d
encodePnmImage (TextPnm, x, y, d) = BPPM.stringPPM (x,y) d

mencode :: MPnmImage -> L.ByteString
mencode = encodePnmImage
