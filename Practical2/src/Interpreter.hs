module Interpreter where

import ParseLib.Abstract
import Prelude hiding ((<*), (<$), lookup)

import Data.Map (Map)
import qualified Data.Map as L

import Data.List.Split
import Data.List


import Data.Char (isSpace)
import Control.Monad (replicateM)

import Lexer
import Parser
import Model
import Algebra


data Contents  =  Empty | Lambda | Debris | Asteroid | Boundary deriving (Eq, Show)

type Size      =  Int
type Pos       =  (Int, Int)
type Space     =  Map Pos Contents



-- | Parses a space file that can be found in the examples folder.
parseSpace :: Parser Char Space
parseSpace = do
    (mr, mc) <- parenthesised ((,) <$> natural <* symbol ',' <*> natural)
                <* spaces
    -- read |mr + 1| rows of |mc + 1| characters
    css      <- replicateM (mr + 1) (replicateM (mc + 1) contents)
    -- convert from a list of lists to a finite map representation
    return $ L.fromList $ concat $
            zipWith (\r cs ->
              zipWith (\c d -> ((r, c), d)) [0..] cs) [0..] css
  where
    spaces :: Parser Char String
    spaces = greedy (satisfy isSpace)

    contents :: Parser Char Contents
    contents = choice (Prelude.map (\(f,c) -> f <$ symbol c) contentsTable)
      <* spaces


-- | Conversion table
contentsTable :: [ (Contents, Char)]
contentsTable =  [ (Empty   , '.' )
                 , (Lambda  , '\\')
                 , (Debris  , '%' )
                 , (Asteroid, 'O' )
                 , (Boundary, '#' )]

main = do 
       s <- readFile "../examples/Maze.space"
       let (space:ss) = ParseLib.Abstract.parse parseSpace s
       putStr (printSpace (fst space))
 

-- Exercise 7
printSpace :: Space -> String
printSpace s = (intercalate "\n" (chunksOf (r+1) (L.foldr f [] s))) ++ "\n"
  where f x r = (lu x) : r
        lu :: Contents -> Char
        lu c' = case [ch | (c,ch) <- contentsTable, c == c'] of
                (x:xs) -> x
                otherwise -> '?'
        ((h,r), _) = L.findMax s


-- These three should be defined by you
type Ident = String
type Commands = Cmds
data Heading = West | East | North | South deriving Show-- is this ok?

type Environment = Map Ident Commands

type Stack       =  Commands 
data ArrowState  =  ArrowState Space Pos Heading Stack deriving Show

data Step =  Done  Space Pos Heading
          |  Ok    ArrowState
          |  Fail  String deriving Show


main2 = do 
       s <- readFile "../examples/Add.arrow"
       putStr (show(alexScanTokens s))

mainp = do 
       s <- readFile "../examples/Add.arrow"
       let t = (alexScanTokens s)
       putStr (show (Parser.parseTokens t)) 

-- | Exercise 8
toEnvironment :: String -> Environment
toEnvironment s = if check p then foldr (\(Rule rstr cs) m -> L.insert rstr cs m) L.empty rs else error "Program did not pass all checks"
  where p@(Program rs) = Parser.parseTokens $ alexScanTokens s

maine = do 
       s <- readFile "../examples/Add.arrow"
       putStr (show (toEnvironment s)) 

check = checkProgram

-- | Exercise 9

updatePos :: Pos -> Heading -> Pos
updatePos (x,y) West  = (x,  y-1)
updatePos (x,y) East  = (x,  y+1)
updatePos (x,y) North = (x-1,  y)
updatePos (x,y) South = (x+1,  y)

updateHeading :: Heading -> Dir -> Heading
updateHeading West LEFT = South
updateHeading West RIGHT = North
updateHeading North LEFT = West
updateHeading North RIGHT = East
updateHeading East LEFT = North
updateHeading East RIGHT = South
updateHeading South LEFT = East
updateHeading South RIGHT = West
updateHeading h    FRONT = h

updatePosWDir :: Pos -> Dir -> Heading -> Pos
updatePosWDir pos dir h =  updatePos pos (updateHeading h dir)


mains = do
       s <- readFile "../examples/AddInput.space"
       let (space:ss) = ParseLib.Abstract.parse parseSpace s
       a <- readFile "../examples/Add.arrow"
       let env = (toEnvironment a)
       putStr ("\n" ++ (show env) ++ "\n\n")
       let as = ArrowState (fst space) (0,0) East (Cmds [(CASE FRONT 
                                                            (Alts [(Alt LAMBDA (Cmds([GO, GO, GO, GO,GO, MARK])))])
                                                          )])
       putStr (show (step env as)) 

step :: Environment -> ArrowState -> Step
step env as@(ArrowState space pos heading (Cmds stack) ) = 
  case stack of
  (GO : xs) -> case L.lookup newPos space of
              (Just Empty)  -> Ok (ArrowState space newPos heading (Cmds xs))
              (Just Lambda) -> Ok (ArrowState space newPos heading (Cmds xs))
              (Just Debris) -> Ok (ArrowState space newPos heading (Cmds xs))
              _             -> ignore xs

  (TAKE : xs) -> case L.lookup pos space of
              (Just Lambda) -> Ok (ArrowState (L.insert pos Empty space) pos heading (Cmds xs))
              (Just Debris) -> Ok (ArrowState (L.insert pos Empty space) pos heading (Cmds xs))
              _             -> ignore xs
  (MARK : xs) ->  Ok (ArrowState (L.insert pos Lambda space) pos heading (Cmds xs))
  (NOTHING : xs) -> ignore xs
  ((TURN dir) : xs) -> Ok (ArrowState space pos (updateHeading heading dir) (Cmds xs))
  ((CASE x (Alts alts) ) : xs) -> let content = case L.lookup (updatePosWDir pos x heading) space of 
                                                  Nothing -> Boundary
                                                  Just c -> c in
                                      let list = [cmds | (Alt pat cmds) <- alts, (isSame content pat)] in
                                        case list of 
                                          [] -> Fail ("Did not create option " ++ (show content) ++ " in case of \n") 
                                          (Cmds l:_) -> Ok (ArrowState space pos heading (Cmds (l ++ xs) ) )
                     
  ((CMD s) : xs) ->  case L.lookup s env of
                    Nothing -> Fail ("Cannot find command \"" ++ s ++ "\"")
                    Just (Cmds c) -> Ok (ArrowState space pos heading (Cmds (c++xs)) )
  [] -> Done space pos heading

  where newPos = updatePos pos heading
        isSame :: Contents -> Pat -> Bool
        isSame Lambda LAMBDA = True
        isSame Empty EMPTY = True
        isSame Debris DEBRIS = True
        isSame Asteroid ASTEROID = True
        isSame Boundary BOUNDARY = True
        isSame _        UNDERSCORE = True
        isSame _        _        = False
        ignore rules = Ok (ArrowState space pos heading (Cmds rules))
        


