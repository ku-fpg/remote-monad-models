{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}



import  Control.Remote.Monad 
import  Control.Remote.Monad.Packet.Applicative
import  Control.Natural (nat, run)
import  System.Random (randomRIO)


data Shape :: * where
   Square    :: Int ->        Shape
   Diamond   ::               Shape
   Rectangle :: Int -> Int -> Shape


square :: Shape
square = Square 4 

diamond :: Shape
diamond = Diamond

rectangle :: Shape
rectangle = Rectangle 5 3

data MyCommand :: * where
   Color   :: String  -> MyCommand
   Stroke  :: String  -> MyCommand
   Draw    :: Shape   -> MyCommand

data MyProcedure :: * -> * where
   Screen ::  MyProcedure (Int,Int)
   Uptime ::  MyProcedure (Double)


getScreen :: RemoteMonad MyCommand MyProcedure (Int,Int)
getScreen = procedure Screen

drawShape :: Shape -> RemoteMonad MyCommand MyProcedure ()
drawShape sh = command (Draw sh) 

uptime:: RemoteMonad MyCommand MyProcedure Double
uptime = procedure Uptime
------------------------ Server Code ------------------------
applicativeDispatch :: ApplicativePacket MyCommand MyProcedure a -> IO a
applicativeDispatch (Procedure ap x) = applicativeDispatch ap <*> procedureDispatch x
applicativeDispatch (Command ap x)   = do commandDispatch x
                                          applicativeDispatch ap
applicativeDispatch (Pure a) = return a

procedureDispatch :: MyProcedure a -> IO a
-- Our screen is a fixed size of 100 x 100
procedureDispatch (Screen) = return (100,100)
procedureDispatch (Uptime) = randomRIO (10,1000)

commandDispatch :: MyCommand -> IO ()
commandDispatch (Color c) = undefined
commandDispatch (Stroke style)= undefined
commandDispatch (Draw sh)= do putStrLn "Start Remote Draw\n"
                              draw sh
                              putStrLn "\nEnd Remote Draw"
                  where draw:: Shape -> IO()
                        draw (Square w )     = mkLines w w
                        draw (Rectangle w h) = mkLines w h
                        draw (Diamond)       = do 
                                       
                                       putStrLn "     *     "
                                       putStrLn "   * * *   "
                                       putStrLn " * * * * * "
                                       putStrLn "   * * *   "
                                       putStrLn "     *     "
                        line :: Int -> IO ()
                        line x 
                          |  x <= 0     = return ()
                          |  otherwise  = do putStr " * " 
                                             line (x -1)
                        
                        mkLines :: Int -> Int -> IO ()
                        mkLines w h 
                         | h <= 0    = return ()
                         | otherwise = do line w
                                          putStrLn ""
                                          mkLines w (h-1)


send :: RemoteMonad MyCommand MyProcedure a -> IO a
send = run $ runMonad $ nat applicativeDispatch


main:: IO()
main =do 
      putStrLn "Let's draw things"
      (screenSize,time) <- send $ do
                       drawShape diamond
                       x <- getScreen
                       drawShape rectangle
                       drawShape square
                       y <- uptime
                       return (x,y)
       
      putStrLn $  "Local: Screen size: "++ (show screenSize)
      putStrLn $  "Local: Uptime: " ++ (show time)++ " hours"

      putStrLn "Let's draw things in Applicative"
      (screenSize,time) <- send $ do
                       pure (,) <* drawShape diamond 
                       <*> getScreen
                       <* drawShape rectangle 
                       <* drawShape square
                       <*> uptime
       
      putStrLn $  "Local: Screen size: "++ (show screenSize)
      putStrLn $  "Local: Uptime: " ++ (show time)++ " hours"

