{-# LANGUAGE CPP                #-}

module Check where

import Test.QuickCheck
import Test.QuickCheck.Monadic (assert, monadicIO, run)

import qualified Parallel as P

import Control.Exception
import Control.Monad

import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Lazy.Char8 as LC8
import Data.Maybe

import System.Random
import System.Process
import System.Posix
import System.Exit
import System.Directory
import System.IO.Unsafe
import System.Timeout

import Data.ByteString.Char8 as L8

#ifdef NET

import Network hiding (accept, sClose)
import Network.Socket hiding (send, sendTo, recv, recvFrom) 
import Network.Socket.ByteString (send, sendTo, recv, recvFrom, sendAll)
import Control.Concurrent
import Control.Concurrent.Thread.Delay

#endif

import Exceptions
import Mutation

processPar = P.processPar
parallelism = P.parallelism

getFileSize :: String -> IO FileOffset
getFileSize path = do
    stat <- getFileStatus path
    return (fileSize stat)

--bhandler :: SomeException -> IO L.ByteString
--bhandler x = return (LC8.pack "") --Prelude.putStrLn (show x)--return ()


--quickhandler x = Nothing

genprop filename prog args encode outdir x = 
         monadicIO $ do
         seed <- run (randomIO :: IO Int)
         sfilename <- run $ return (outdir ++ "/" ++ show seed ++ "." ++ filename)
         --run $ print x
         run $ Control.Exception.catch (L.writeFile sfilename (encode x)) handler
         size <- run $ getFileSize sfilename
         if size == 0 
            then (do 
                    run $ removeFile sfilename
                    Test.QuickCheck.Monadic.assert True)
            else
              Test.QuickCheck.Monadic.assert True


checkprop filename prog args encode outdir x = 
         monadicIO $ do
         run $ Control.Exception.catch (L.writeFile filename (encode x)) handler
         size <- run $ getFileSize filename
         if size == 0 
            then Test.QuickCheck.Monadic.assert True 
         else (
           do 
               let varepname = filename ++ ".vreport.out"
               seed <- run (randomIO :: IO Int)
               ret <- run $ rawSystem "/usr/bin/valgrind" (["--log-file="++ varepname, "--quiet", prog] ++ args)
               size <- run $ getFileSize varepname --"vreport.out"
               if size > 0 
                  then ( 
                      do 
                        run $ copyFile varepname (outdir ++ "/" ++ "vreport.out."++ show seed)
                        -- run $ copyFile "vreport.out" (outdir ++ "/" ++ "vreport.out."++ show seed)
                        run $ copyFile filename (outdir ++ "/" ++ filename ++ "."++ show seed)
                        Test.QuickCheck.Monadic.assert True
                      )
                  else Test.QuickCheck.Monadic.assert True
               )

call_honggfuzz filename exprog args seed outdir = 
   rawSystem "honggfuzz" (["-q", "-v", "-n", "2", "-N", "5", "-r", "0.00001", "-t","60", "-f", filename,  "-W", outdir, "--", exprog] ++ args)

honggprop :: FilePath -> FilePath -> [String] -> (t -> L.ByteString) -> FilePath -> t -> Property
honggprop filename prog args encode outdir x = 
            noShrinking $ monadicIO $ do
               run $ Control.Exception.catch (L.writeFile filename (encode x)) handler
               size <- run $ getFileSize filename
               when (size > 0) $ do
               --   (Test.QuickCheck.Monadic.assert True) $ do
                 ret <- run $ call_honggfuzz filename prog args undefined outdir
                 Test.QuickCheck.Monadic.assert True


-- write_and_check filename encode x =    
call_zzuf filename exprog args seed outdir = 
  rawSystem "zzuf" (["-M", "-1", "-q", "-r","0.004:0.000001", "-s", show seed ++":"++ show (seed+50), "-I", filename, "-S", "-T", "5", "-j", "1", exprog] ++ args)

zzufprop :: FilePath -> FilePath -> [String] -> (t -> L.ByteString) -> FilePath -> t -> Property
zzufprop filename prog args encode outdir x = 
            noShrinking $ monadicIO $ do
            --run $ createDirectoryIfMissing False outdir
            run $ Control.Exception.catch (L.writeFile filename (encode x)) handler
            size <- run $ getFileSize filename
            unless (size > 0) 
              (Test.QuickCheck.Monadic.assert True)
            seed <- run (randomIO :: IO Int)
            ret <- run $ call_zzuf filename prog args seed outdir
            case ret of
              ExitFailure x ->do
                             run $ copyFile filename (outdir ++ "/" ++ filename ++ "."++ show seed)
                             Test.QuickCheck.Monadic.assert True
              _             -> Test.QuickCheck.Monadic.assert True


radamprop filename prog args encode outdir x = 
         noShrinking $ monadicIO $ do
         let tmp_filename = ".qf." ++ filename
         run $  Control.Exception.catch (L.writeFile tmp_filename (encode x)) handler
         size <- run $ getFileSize tmp_filename
         if size == 0 
            then Test.QuickCheck.Monadic.assert True 
         else (
           do 
           seed <- run (randomIO :: IO Int)
           run $ system $ "radamsa" ++ "<" ++ tmp_filename ++ " > " ++ filename
           ret <- run $ rawSystem prog args
           --run $ putStrLn (show ret)
           case ret of
              ExitFailure x -> (
                                
                                if (x < 0 || x > 128) then
                                 do 
                                   run $ copyFile filename (outdir ++ "/" ++ filename ++ "."++ show seed)
                                   Test.QuickCheck.Monadic.assert True
                                 else
                                   Test.QuickCheck.Monadic.assert True
                )
              _             -> Test.QuickCheck.Monadic.assert True
           )



timed_encode f x = unsafePerformIO ( 
             do r <- timeout 10000 $ evaluate $ f x
                case r of
                  Just x -> return x --unsafePerformIO $ return x
                  Nothing -> return $ LC8.pack "" --unsafePerformIO $ return $ LC8.pack ""
             )


--mutprop :: (Show a, Mutation a,Arbitrary a) => FilePath  -> String -> [String]  -> (a -> L.ByteString) -> (L.ByteString -> a) -> [Char] -> [a] ->  Property
mutprop filename prog args encode outdir maxsize vals = 
         noShrinking $ monadicIO $ do
         r <- run (randomIO :: IO Int)
         idx <- run $ return (r `mod` (Prelude.length vals))
         size <- run $ return (r `mod` maxsize)
         run $ print "Mutating.."

         x <- run $ return $ vals !! idx
         y <- run $ generate $ resize size $ mutt $ x
         --run $ print "Original:"
         --run $ print ("Idx: "++show(idx))

         --run $ print x --Control.Exception.catch (print x) handler

         --run $ print y --Control.Exception.catch (print y) handler
         run $ print "Encoding.."

         z <- run $ Control.Exception.catch (evaluate $ timed_encode encode y) enc_handler
         let tmp_filename = ".qf." ++ filename
         run $ (L.writeFile tmp_filename z)
         run $ system $ "radamsa" ++ "<" ++ tmp_filename ++ " > " ++ filename

         run $ print "Executing.."

         size <- run $ getFileSize filename 
         if size == 0 
            then Test.QuickCheck.Monadic.assert True 
         else (
           do 
           seed <- run (randomIO :: IO Int)
           ret <- run $ rawSystem prog args
           --ret <- run $ call_honggfuzz filename prog args undefined outdir

           case ret of
              ExitFailure x -> (
                                
                                if ((x < 0 || x > 128) && x /= 143) then
                                 do 
                                   run $ copyFile filename (outdir ++ "/" ++ show seed ++ "." ++ filename)
                                   Test.QuickCheck.Monadic.assert True
                                 else
                                   Test.QuickCheck.Monadic.assert True
                )
              _             -> Test.QuickCheck.Monadic.assert True
           )
         --)





execprop filename prog args encode outdir x = 
         noShrinking $ monadicIO $ do
         --run $ Prelude.putStrLn (show x)
         run $  Control.Exception.catch (L.writeFile filename (encode x)) handler
         size <- run $ getFileSize filename
         if size == 0 
            then Test.QuickCheck.Monadic.assert True 
         else (
           do 
           seed <- run (randomIO :: IO Int)
           --run $ system $ "/usr/bin/zzuf -r 0.004:0.000001 -s" ++ (show (seed `mod` 10024))++":"++(show (seed `mod` 10024 + 1)) ++ "<" ++ filename ++ " > " ++ filename ++ ".fuzzed"
           ret <- run $ rawSystem prog args
           --run $ putStrLn (show ret)
           case ret of
              ExitFailure x -> (
                                
                                if ((x < 0 || x > 128) && x /= 143) then
                                 do
                                   run $ copyFile filename (outdir ++ "/" ++ show seed ++ "." ++ filename)
                                   Test.QuickCheck.Monadic.assert True
                                 else
                                   Test.QuickCheck.Monadic.assert True
                )
              _             -> Test.QuickCheck.Monadic.assert True
           )


#ifdef NET

serve :: PortNumber -> [L8.ByteString] -> IO ()
serve port xs = withSocketsDo $ do
    sock <- listenOn $ PortNumber port
    serve_loop sock xs

serve_loop sock (x:xs) = do
   Prelude.putStrLn "Accepting connection.."
   (conn, _) <- accept sock
   forkIO $ body conn
   serve_loop sock xs
  where
   body c = do sendAll c x
               sClose c

serve_loop _ [] = error "Empty list!"

serveprop port _ encode x =  
        noShrinking $ monadicIO $ do
           run $ serve port (encode x)
           Test.QuickCheck.Monadic.assert True

cconnect :: PortNumber -> String -> [L8.ByteString] -> IO ()
cconnect port host xs = withSocketsDo $ do
    Prelude.putStrLn host
    Prelude.putStrLn (show port)
    addrInfo <- getAddrInfo Nothing (Just host) (Just $ show port)

    let serverAddr = Prelude.head addrInfo
    sock <- socket (addrFamily serverAddr) Stream defaultProtocol
    --sock <- conn $ PortNumber port
    connect sock (addrAddress serverAddr)
    cconect_loop sock xs

cconect_loop sock (x:xs) = do
   Prelude.putStrLn "Sending data .."
   send sock x
   --(conn, _) <- accept sock
   --forkIO $ body conn
   cconnect_loop sock xs
  --where
  -- body c = do sendAll c x
  --             sClose c

cconnect_loop _ [] = error "Empty list!"

cconnectprop port host encode x =  
        noShrinking $ monadicIO $ do
           run $ cconnect port host (encode x)
           Test.QuickCheck.Monadic.assert True

#endif
