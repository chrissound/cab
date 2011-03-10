module CmdDB where

import Commands
import Control.Monad
import Data.List
import Program
import System.Exit
import System.IO
import Types
import Utils

----------------------------------------------------------------

commandDB :: CommandDB
commandDB = [
    CommandSpec {
         command = Sync
       , commandNames = ["sync", "update"]
       , document = "Fetchinwg the latest package index"
       , routing = RouteProc "cabal" ["update"]
       , options = []
       }
  , CommandSpec {
         command = Install
       , commandNames = ["install"]
       , document = "Install packages"
       , routing = RouteProc "cabal" ["install"]
       , options = [(OptNoHarm, Just "--dry-run")]
       }
  , CommandSpec {
         command = Uninstall
       , commandNames = ["uninstall", "delete", "remove", "unregister"]
       , document = "Uninstalling packages"
       , routing = RouteFunc uninstall
       , options = [(OptNoHarm, Nothing)
                   ,(OptRecursive, Nothing)
                   ] -- don't allow OptAll
       }
  , CommandSpec {
         command = Installed
       , commandNames = ["installed", "list"]
       , document = "Listing installed packages"
       , routing = RouteFunc installed
       , options = [(OptAll, Nothing)]
       }
  , CommandSpec {
         command = Configure
       , commandNames = ["configure", "conf"]
       , document = "Configuring a cabal package"
       , routing = RouteProc "cabal" ["configure"]
       , options = []
       }
  , CommandSpec {
         command = Build
       , commandNames = ["build"]
       , document = "Building a cabal package"
       , routing = RouteProc "cabal" ["build"]
       , options = []
       }
  , CommandSpec {
         command = Clean
       , commandNames = ["clean"]
       , document = "Cleaning a build directory"
       , routing = RouteProc "cabal" ["clean"]
       , options = []
       }
  , CommandSpec {
         command = Outdated
       , commandNames = ["outdated"]
       , document = "Displaying outdated packages"
       , routing = RouteFunc outdated
       , options = [(OptAll, Nothing)]
       }
  , CommandSpec {
         command = Info
       , commandNames = ["info"]
       , document = "Display information of a package"
       , routing = RouteProc "cabal" ["info"]
       , options = []
       }
  , CommandSpec {
         command = Sdist
       , commandNames = ["sdist"]
       , document = "Make tar.gz for source distribution"
       , routing = RouteProc "cabal" ["sdist"]
       , options = []
       }
  , CommandSpec {
         command = Unpack
       , commandNames = ["unpack"]
       , document = "Untar a package in the current directory"
       , routing = RouteProc "cabal" ["unpack"]
       , options = []
       }
  , CommandSpec {
         command = Deps
       , commandNames = ["deps"]
       , document = "Show dependencies of this package"
       , routing = RouteFunc deps
       , options = [(OptRecursive, Nothing)
                   ,(OptAll, Nothing)
                   ]
       }
  , CommandSpec {
         command = RevDeps
       , commandNames = ["revdeps", "dependents"]
       , document = "Show reverse dependencies of this package"
       , routing = RouteFunc revdeps
       , options = [(OptRecursive, Nothing)
                   ,(OptAll, Nothing)
                   ]
       }
  , CommandSpec {
         command = Check
       , commandNames = ["check"]
       , document = "Check consistency of packages"
       , routing = RouteProc "ghc-pkg" ["check"]
       , options = []
       }
  , CommandSpec {
         command = Help
       , commandNames = ["help"]
       , document = undefined
       , routing = RouteFunc helpCommandAndExit
       , options = []
       }
  ]

----------------------------------------------------------------

optionDB :: OptionDB
optionDB = [
    OptionSpec {
         option = OptNoHarm
       , optionNames = ["--dry-run", "-n"]
       , optionDesc = "Run without destructive operations"
       }
  , OptionSpec {
         option = OptRecursive
       , optionNames = ["--recursive", "-r"]
       , optionDesc = "Follow dependencies recursively"
       }
  , OptionSpec {
         option = OptAll
       , optionNames = ["--all", "-a"]
       , optionDesc = "Show global packages in addition to user packages"
       }
  ]

----------------------------------------------------------------

commandSpecByName :: String -> CommandDB -> Maybe CommandSpec
commandSpecByName _ [] = Nothing
commandSpecByName x (ent:ents)
    | x `elem` commandNames ent = Just ent
    | otherwise                 = commandSpecByName x ents

optionSpecByName :: String -> OptionDB -> Maybe OptionSpec
optionSpecByName _ [] = Nothing
optionSpecByName x (ent:ents)
    | x `elem` optionNames ent = Just ent
    | otherwise                = optionSpecByName x ents

----------------------------------------------------------------

helpCommandAndExit :: FunctionCommand
helpCommandAndExit _ [] _ = helpAndExit
helpCommandAndExit _ (cmd:_) _ = do
    case mcmdspec of
        Nothing -> helpAndExit
        Just cmdspec -> do
            putStrLn $ "Usage: " ++ cmd ++ " " ++ showOptions cmdspec
            putStr "\n"
            putStrLn $ document cmdspec
            putStr "\n"
            putStrLn $ "Aliases: " ++ showAliases cmdspec
            putStr "\n"
            printOptions cmdspec
    exitSuccess
  where
    mcmdspec = commandSpecByName cmd commandDB
    showOptions cmdspec = joinBy " " $ concatMap (masterOption optionDB) (opts cmdspec)
    opts = map fst . options
    masterOption [] _ = []
    masterOption (spec:specs) o
      | option spec == o = (head . optionNames $ spec) : masterOption specs o
      | otherwise        = masterOption specs o
    showAliases = joinBy ", " . commandNames

printOptions :: CommandSpec -> IO ()
printOptions cmdspec =
    forM_ opts (printOption optionDB)
  where
    opts = map fst $ options cmdspec
    printOption [] _ = return ()
    printOption (spec:specs) o
      | option spec == o =
          putStrLn $ (joinBy ", " . reverse . optionNames $ spec)
                   ++ "\t" ++ optionDesc spec
      | otherwise        = printOption specs o

----------------------------------------------------------------

helpAndExit :: IO ()
helpAndExit = do
    putStrLn $ programName ++ " " ++ " -- " ++ description
    putStrLn ""
    putStrLn $ "Version: " ++ version
    putStrLn "Usage:"
    putStrLn $ "\t" ++ programName
    putStrLn $ "\t" ++ programName ++ " <command> [args...]"
    putStrLn $ "\t  where"
    printCommands (getCommands commandDB)
    exitSuccess
  where
    getCommands = map concat
                . split helpCommandNumber
                . intersperse ", "
                . map head
                . map commandNames
    printCommands [] = return ()
    printCommands (x:xs) = do
        putStrLn $ "\t    <command> = " ++ x
        mapM_ (\cmds -> putStrLn $ "\t                " ++ cmds) xs

helpCommandNumber :: Int
helpCommandNumber = 10

----------------------------------------------------------------

illegalCommandAndExit :: String -> IO ()
illegalCommandAndExit x = do
    hPutStrLn stderr $ "Illegal command: " ++ x
    exitFailure

----------------------------------------------------------------

illegalOptionsAndExit :: [String] -> IO ()
illegalOptionsAndExit xs = do -- FixME
    hPutStrLn stderr $ "Illegal options: " ++ concat (intersperse " " xs)
    exitFailure