@echo off

REM blaze-add, add a blog post or a page to the BlazeBlogger repository
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

set BLAZECOMMAND=%~n0
call blaze.bat %*
set BLAZECOMMAND=