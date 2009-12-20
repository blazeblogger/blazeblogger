@echo off

REM blaze, a command wrapper for BlazeBlogger
REM Copyright (C) 2009 Sergey Kuznetsov
REM
REM This program is  free software:  you can redistribute it and/or modify it
REM under  the terms  of the  GNU General Public License  as published by the
REM Free Software Foundation, version 3 of the License.
REM
REM This program  is  distributed  in the hope  that it will  be useful,  but
REM WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
REM BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
REM License for more details.
REM
REM You should have received a copy of the  GNU General Public License  along
REM with this program. If not, see <http://www.gnu.org/licenses/>.

set BLAZENAME=%~n0
set BLAZEVERSION=1.0.0

if defined BLAZECOMMAND (
	perl %~d0%~p0..\src\%BLAZECOMMAND%.pl %*
	goto :EOF
)

if exist blaze-%1.bat (
	call blaze-%1.bat %2 %3 %4 %5 %6 %7 %8 %9
	goto :EOF
)

if /i "%1"=="help" (
	if exist blaze-%2.bat (
		call blaze-%2.bat -h
		goto :EOF
	)
)

echo Usage: %BLAZENAME% COMMAND [OPTION...]
echo.
echo Available commands:
echo   init    Create or recover a BlazeBlogger repository.
echo   config  Display or set the BlazeBlogger repository options.
echo   add     Add new post or a page to the BlazeBlogger repository.
echo   edit    Edit a post or page in the BlazeBlogger repository.
echo   remove  Remove a post or page from the BlazeBlogger repository.
echo   list    Browse the content of the BlazeBlogger repository.
echo   make    Generate static content from the BlazeBlogger repository.
echo   log     Display the BlazeBlogger repository log.
echo.
echo Type \`%BLAZENAME% help COMMAND' for command details.