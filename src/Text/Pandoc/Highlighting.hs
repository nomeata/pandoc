{-
Copyright (C) 2008-2016 John MacFarlane <jgm@berkeley.edu>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- |
   Module      : Text.Pandoc.Highlighting
   Copyright   : Copyright (C) 2008-2016 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Exports functions for syntax highlighting.
-}

module Text.Pandoc.Highlighting ( languages
                                , languagesByExtension
                                , highlight
                                , formatLaTeXInline
                                , formatLaTeXBlock
                                , styleToLaTeX
                                , formatHtmlInline
                                , formatHtmlBlock
                                , styleToCss
                                , pygments
                                , espresso
                                , zenburn
                                , tango
                                , kate
                                , monochrome
                                , haddock
                                , Style
                                , fromListingsLanguage
                                , toListingsLanguage
                                ) where
import Text.Pandoc.Definition
import Text.Pandoc.Shared (safeRead)
import Skylighting
import Data.Maybe (fromMaybe)
import Data.Char (toLower)
import qualified Data.Map as M
import Control.Monad
import qualified Data.Text as T

languages :: [String]
languages = [T.unpack (T.toLower (sName s)) | s <- M.elems defaultSyntaxMap]

languagesByExtension :: String -> [String]
languagesByExtension ext =
  [T.unpack (T.toLower (sName s)) | s <- syntaxesByExtension defaultSyntaxMap ext]

highlight :: (FormatOptions -> [SourceLine] -> a) -- ^ Formatter
          -> Attr   -- ^ Attributes of the CodeBlock
          -> String -- ^ Raw contents of the CodeBlock
          -> Maybe a -- ^ Maybe the formatted result
highlight formatter (_, classes, keyvals) rawCode =
  let firstNum = fromMaybe 1 (safeRead (fromMaybe "1" $ lookup "startFrom" keyvals))
      fmtOpts = defaultFormatOpts{
                  startNumber = firstNum,
                  numberLines = any (`elem`
                        ["number","numberLines", "number-lines"]) classes }
      tokenizeOpts = TokenizerConfig{ syntaxMap = defaultSyntaxMap
                                    , traceOutput = False }
      classes' = map T.pack classes
      rawCode' = T.pack rawCode
  in  case msum (map (\l -> lookupSyntax l defaultSyntaxMap) classes') of
            Nothing
              | numberLines fmtOpts -> Just
                              $ formatter fmtOpts{ codeClasses = [],
                                                   containerClasses = classes' }
                              $ map (\ln -> [(NormalTok, ln)]) $ T.lines rawCode'
              | otherwise  -> Nothing
            Just syntax  ->
              case tokenize tokenizeOpts syntax rawCode' of
                   Right slines -> Just $
                         formatter fmtOpts{ codeClasses =
                                               [T.toLower (sShortname syntax)],
                                            containerClasses = classes' } slines
                   Left _ -> Nothing

-- Functions for correlating latex listings package's language names
-- with skylighting language names:

langToListingsMap :: M.Map String String
langToListingsMap = M.fromList langsList

listingsToLangMap :: M.Map String String
listingsToLangMap = M.fromList $ map switch langsList
  where switch (a,b) = (b,a)

langsList :: [(String, String)]
langsList =
  [("abap","ABAP"),
  ("acm","ACM"),
  ("acmscript","ACMscript"),
  ("acsl","ACSL"),
  ("ada","Ada"),
  ("algol","Algol"),
  ("ant","Ant"),
  ("assembler","Assembler"),
  ("gnuassembler","Assembler"),
  ("awk","Awk"),
  ("bash","bash"),
  ("monobasic","Basic"),
  ("purebasic","Basic"),
  ("c","C"),
  ("cpp","C++"),
  ("c++","C++"),
  ("ocaml","Caml"),
  ("cil","CIL"),
  ("clean","Clean"),
  ("cobol","Cobol"),
  ("comal80","Comal80"),
  ("command.com","command.com"),
  ("comsol","Comsol"),
  ("csh","csh"),
  ("delphi","Delphi"),
  ("elan","Elan"),
  ("erlang","erlang"),
  ("euphoria","Euphoria"),
  ("fortran","Fortran"),
  ("gap","GAP"),
  ("gcl","GCL"),
  ("gnuplot","Gnuplot"),
  ("hansl","hansl"),
  ("haskell","Haskell"),
  ("html","HTML"),
  ("idl","IDL"),
  ("inform","inform"),
  ("java","Java"),
  ("jvmis","JVMIS"),
  ("ksh","ksh"),
  ("lingo","Lingo"),
  ("lisp","Lisp"),
  ("commonlisp","Lisp"),
  ("llvm","LLVM"),
  ("logo","Logo"),
  ("lua","Lua"),
  ("make","make"),
  ("makefile","make"),
  ("mathematica","Mathematica"),
  ("matlab","Matlab"),
  ("mercury","Mercury"),
  ("metapost","MetaPost"),
  ("miranda","Miranda"),
  ("mizar","Mizar"),
  ("ml","ML"),
  ("modula2","Modula-2"),
  ("mupad","MuPAD"),
  ("nastran","NASTRAN"),
  ("oberon2","Oberon-2"),
  ("ocl","OCL"),
  ("octave","Octave"),
  ("oz","Oz"),
  ("pascal","Pascal"),
  ("perl","Perl"),
  ("php","PHP"),
  ("pli","PL/I"),
  ("plasm","Plasm"),
  ("postscript","PostScript"),
  ("pov","POV"),
  ("prolog","Prolog"),
  ("promela","Promela"),
  ("pstricks","PSTricks"),
  ("python","Python"),
  ("r","R"),
  ("reduce","Reduce"),
  ("rexx","Rexx"),
  ("rsl","RSL"),
  ("ruby","Ruby"),
  ("s","S"),
  ("sas","SAS"),
  ("scala","Scala"),
  ("scilab","Scilab"),
  ("sh","sh"),
  ("shelxl","SHELXL"),
  ("simula","Simula"),
  ("sparql","SPARQL"),
  ("sql","SQL"),
  ("tcl","tcl"),
  ("tex","TeX"),
  ("latex","TeX"),
  ("vbscript","VBScript"),
  ("verilog","Verilog"),
  ("vhdl","VHDL"),
  ("vrml","VRML"),
  ("xml","XML"),
  ("xslt","XSLT")]

-- | Determine listings language name from skylighting language name.
toListingsLanguage :: String -> Maybe String
toListingsLanguage lang = M.lookup (map toLower lang) langToListingsMap

-- | Determine skylighting language name from listings language name.
fromListingsLanguage :: String -> Maybe String
fromListingsLanguage lang = M.lookup lang listingsToLangMap
