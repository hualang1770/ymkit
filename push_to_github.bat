@echo off
chcp 936 >nul 2>nul
setlocal
cd /d "%~dp0"

rem ============================================================
rem  ymkit 一键推送到 GitHub
rem  仓库地址：https://github.com/hualang1770/ymkit.git
rem
rem  用法：
rem    push_to_github.bat                 自动生成提交说明并推送
rem    push_to_github.bat "提交说明"      用指定说明提交（说明里有空格要加引号）
rem    push_to_github.bat -n              预演，只看会提交哪些文件，不动仓库
rem
rem  流程：暂存当前目录所有改动 -> 提交 -> 推送到 origin 的当前分支。
rem        推送被拒（远端有新提交）时会先 git pull --rebase 再推一次。
rem        第一次推送如果弹出登录窗口，用 GitHub 账号登录一次，以后就不用再登了。
rem
rem  注意：本文件要保存成 GBK/ANSI 编码，存成 UTF-8 会让 cmd 里的中文变乱码。
rem ============================================================

set "REPO_URL=https://github.com/hualang1770/ymkit.git"
set "DRY="
set "MSG="
if /i "%~1"=="/?"     goto usage
if /i "%~1"=="-h"     goto usage
if /i "%~1"=="--help" goto usage
if /i "%~1"=="-n" ( set "DRY=1" & set "MSG=%~2" ) else ( set "MSG=%~1" )
if "%MSG%"=="" set "MSG=更新 ymkit %DATE% %TIME%"

echo ============================================================
echo   ymkit 推送到 GitHub
echo ============================================================
echo.

rem ---------- 1. 环境检查 ----------
where git >nul 2>nul
if errorlevel 1 (
    echo [错误] 找不到 git 命令，请先安装 Git，并确保它能被 PATH 找到。
    goto fail
)

git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo [错误] 当前目录不是 git 仓库：%CD%
    echo        请把本脚本放在 ymkit 模组目录里再运行。
    goto fail
)

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%b"
if not defined BRANCH (
    echo [错误] 读不出当前分支名。
    goto fail
)
if /i "%BRANCH%"=="HEAD" (
    echo [错误] 仓库现在是游离头指针状态，先执行 git switch main 回到分支上。
    goto fail
)

git remote get-url origin >nul 2>nul
if errorlevel 1 (
    echo [错误] 没有配置远程仓库 origin，可以先执行：
    echo        git remote add origin %REPO_URL%
    goto fail
)
for /f "delims=" %%u in ('git remote get-url origin') do set "ORIGIN=%%u"

echo 目录：%CD%
echo 远程：%ORIGIN%
echo 分支：%BRANCH%
echo.

echo ---------- 当前改动 ----------
git -c core.quotepath=false status --short
echo.

if defined DRY (
    echo [预演] 上面就是要提交的内容，本次没有暂存、提交、推送。
    goto done
)

rem ---------- 2. 暂存 ----------
echo ---------- 暂存所有改动：git add -A ----------
git add -A
if errorlevel 1 (
    echo [错误] git add 失败。
    goto fail
)

rem ---------- 3. 提交 ----------
git diff --cached --quiet
if errorlevel 1 (
    echo ---------- 提交：%MSG% ----------
    git commit -m "%MSG%"
    if errorlevel 1 (
        echo [错误] git commit 失败。
        goto fail
    )
) else (
    echo ---------- 没有新改动要提交，直接推送已有提交 ----------
)
echo.

rem ---------- 4. 推送 ----------
echo ---------- 推送到 %ORIGIN% 的 %BRANCH% ----------
git push -u origin "%BRANCH%"
if errorlevel 1 (
    echo.
    echo 推送被拒绝，远端可能有新的提交，先拉取再重试...
    git pull --rebase origin "%BRANCH%"
    if errorlevel 1 (
        echo.
        echo [错误] 拉取 / 变基失败，多半是同一个文件两边都改了。
        echo        手动改好冲突后再 git add 然后 git rebase --continue；
        echo        想放弃这次拉取就执行 git rebase --abort。
        goto fail
    )
    git push -u origin "%BRANCH%"
    if errorlevel 1 (
        echo [错误] 还是推不上去，检查一下网络和 GitHub 账号权限。
        goto fail
    )
)

echo.
echo [完成] 已经推送到 %ORIGIN% 了。
goto done

:usage
echo 用法：
echo   push_to_github.bat                自动生成提交说明并推送
echo   push_to_github.bat "提交说明"     用指定说明提交（说明里有空格要加引号）
echo   push_to_github.bat -n             预演，只看会提交哪些文件，不动仓库
goto done

:fail
echo.
echo [失败] 没有推送成功，照着上面的提示处理就好。
endlocal
pause
exit /b 1

:done
echo.
endlocal
pause
exit /b 0