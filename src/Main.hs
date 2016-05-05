{-# LANGUAGE CPP                #-}

module Main where

import qualified Process

#ifdef IMGS

import qualified Tga
import qualified Tiff
import qualified Png
import qualified Jpeg
import qualified Bmp
import qualified Gif
import qualified Pnm
import qualified Svg
import qualified Ico

#endif

#ifdef ARCHS

import qualified Zip
import qualified Tar
import qualified Gzip
import qualified Bzip
import qualified CPIO

#endif

#ifdef CODES

import qualified Xml
import qualified Html
import qualified Css
import qualified Js
import qualified Python
import qualified Dot
import qualified JSON
import qualified GLSL
import qualified Regex

#endif

#ifdef DOCS

import qualified Pandoc
import qualified PS

#endif

#ifdef NET

import qualified URI
import qualified Http
--import qualified Dns

#endif

#ifdef MEDIA

import qualified Ogg
--import qualified Sh
import qualified Midi
import qualified ID3
import qualified TTF
import qualified Wav

#endif

--import qualified MBox
import qualified ByteString
import qualified Unicode

--import qualified MarkUpSvg


import System.Console.ArgParser
import System.Random
import Args
import Data.Maybe
import System.Directory 
import System.Exit
import Control.Monad
import Data.List.Split

fillArgs :: MainArgs -> IO (String -> MainArgs)
fillArgs args =
    case findFileName args of
        [] -> do
            sG <- getStdGen
            --let fname = take 10 ((randomRs ('a','z') sG) :: String )
            let fname = case findAct args of
                            "honggfuzz" -> "___FILE___"
                            _ -> take 10 ((randomRs ('a','z') sG) :: String )
            return $ formatArgs (formatFileName args fname)
        _ -> return $ formatArgs args

dispatch :: MainArgs -> IO ()
dispatch arg = do
        args <- fillArgs arg
        let b = findPar arg
        safetyChecks arg 
        case findFileType arg of

#ifdef IMGS

            "Bmp"  -> Process.main (Bmp.mencode,undefined, undefined) args b
            "Gif"  -> Process.main (Gif.mencode,Gif.mdecode, undefined) args b
            "Jpeg" -> Process.main (Jpeg.mencode,Jpeg.mdecode, undefined) args b
            "Png"  -> Process.main (Png.mencode,Png.mdecode, undefined) args b
            "Tiff" -> Process.main (Tiff.mencode,undefined, undefined)  args b
            "Tga"  -> Process.main (Tga.mencode,undefined, undefined)  args b
            "Pnm"  -> Process.main (Pnm.mencode,undefined, undefined)  args b
            "Svg"  -> Process.main (Svg.mencode,Svg.mdecode, undefined)  args b
            "Ico"  -> Process.main (Ico.mencode, undefined, undefined)  args b

#endif

#ifdef ARCHS

            "Zip"  -> Process.main (Zip.mencode,undefined,undefiend)  args b
            "Bzip" -> Process.main (Bzip.mencode,undefined,undefined)  args b
            "Gzip" -> Process.main (Gzip.mencode,undefined,undefined)  args b
            "Tar"  -> Process.main (Tar.mencode,undefined,undefined)  args b
            "CPIO" -> Process.main (CPIO.mencode,undefined,undefined)  args b

#endif


#ifdef CODES

            "Dot"  -> Process.main (Dot.mencode,undefined,undefined)  args b
            "Xml"  -> Process.main (Xml.mencode,Xml.mdecode,undefined)  args b
            "Html" -> Process.main (Html.mencode,undefined,undefined)  args b
            "Js"   -> Process.main (Js.mencode,undefined,undefined)  args b
            "Py"   -> Process.main (Python.mencode,undefined,undefined)  args b
            "CSS"  -> Process.main (Css.mencode,undefined,undefined)  args b
            "JSON"   -> Process.main (JSON.mencode,undefined,undefined) args b
            "GLSL"   -> Process.main (GLSL.mencode,undefined,undefined) args b
            "Regex" -> Process.main (Regex.mencode,undefined,undefined)  args b
            --"Sh"   -> Sh.main args b

#endif

#ifdef DOCS
            "Rtf"  -> Process.main (Pandoc.mencode_rtf,undefined,undefined)  args b
            "Docx"  -> Process.main (Pandoc.mencode_docx,undefined,undefined)  args b
            "Odt"  -> Process.main (Pandoc.mencode_odt,undefined,undefined)  args b
            "PS"  -> Process.main (PS.mencode,undefined,undefined)  args b

#endif

#ifdef NET

            "HttpReq" -> Process.netmain Http.mencode_req args b
            "HttpRes" -> Process.netmain Http.mencode_res args b

            --"Tftp" -> Tftp.main args b
            --"Dns" -> Process.netmain Dns.mencode args b
            "URI"   -> Process.main (URI.mencode,undefined,undefined) args b
#endif

#ifdef MEDIA

            "Ogg"  -> Process.main (Ogg.mencode,undefined,undefined)  args b
            "ID3"   -> Process.main (ID3.mencode,undefined,undefined)  args b
            "MIDI"   -> Process.main (Midi.mencode,undefined,undefined)  args b
            "TTF"  -> Process.main (TTF.mencode,undefined,undefined)  args b
            "Wav"  -> Process.main (Wav.mencode,undefined,undefined)  args b

#endif

            --"MarkUp" -> Process.main MarkUp.mencodeHtml args b
            --"MarkUpSvg" -> Process.main MarkUpSvg.mencode args b

            --"MBox"   -> MBox.main args b
            "Unicode" -> Process.main (Unicode.mencode,undefined, undefined)  args b
            "BS"   -> Process.main (ByteString.bencode,undefined, undefined)  args b

            _      -> print "Unsupported Type"

-- | Just checks that the command and the action are executables in the current
-- system
safetyChecks :: MainArgs -> IO ()
safetyChecks args = do
    return ()
    --cmdex <- findExecutable cmd
    --unless (isJust cmdex) (die $ "The command \"" ++ cmd ++ "\" is not present.")
    --let act = findAct args
    --actx <- findExecutable act
    --unless (isJust actx) (die $ "The action \"" ++ act ++ "\" cannot be done.")
        
main = do
    interface <- cli
    runApp interface dispatch
