@echo off
setlocal enabledelayedexpansion
title ComfyUI Setup (Windows)

:: === Paths ===
set "MINIFORGE=%USERPROFILE%\miniforge3"
set "CONDA_BAT=%MINIFORGE%\condabin\conda.bat"
set "SD_ENV=sd"
set "COMFY_DIR=C:\AI_Projects\ComfyUI"

echo [1/9] Checking Miniforge...
if not exist "%CONDA_BAT%" (
  echo   -> Miniforge (conda) が見つかりませんでした。
  echo      https://github.com/conda-forge/miniforge/releases から Miniforge3-Windows-x86_64.exe を入れてください。
  echo      入れたら本バッチを再実行してください。
  pause
  exit /b 1
)

echo [2/9] Creating/activating conda env "%SD_ENV%" (Python 3.11)...
call "%CONDA_BAT%" env list | findstr /I " %SD_ENV% " >nul
if errorlevel 1 (
  call "%CONDA_BAT%" create -n %SD_ENV% python=3.11 -y || goto :err
)
call "%CONDA_BAT%" activate %SD_ENV% || goto :err

echo [3/9] Upgrading pip...
python -m pip install -U pip || goto :err

echo [4/9] Installing base requirements (video-friendly)...
python -m pip install ^
  numpy pillow opencv-python einops safetensors imageio[ffmpeg] av tqdm pyyaml scipy moviepy soundfile || goto :err

echo [5/9] Installing PyTorch (nightly + cu124)...
:: NOTE: torchaudio の nightly/cu124 は Win で未提供のことが多いので入れません
python -m pip install --pre torch --index-url https://download.pytorch.org/whl/nightly/cu124 || goto :err

echo [6/9] Preparing ComfyUI folder...
if not exist "C:\AI_Projects" mkdir "C:\AI_Projects"
if not exist "%COMFY_DIR%" (
  echo   -> Cloning ComfyUI into %COMFY_DIR% ...
  git --version >nul 2>&1 || (echo   -> Git が必要です。https://git-scm.com/ からインストールして再実行してください & goto :err)
  pushd C:\AI_Projects
  git clone https://github.com/comfyanonymous/ComfyUI || (popd & goto :err)
  popd
)
mkdir "%COMFY_DIR%\models" 2>nul
mkdir "%COMFY_DIR%\models\checkpoints" 2>nul
mkdir "%COMFY_DIR%\models\vae" 2>nul
mkdir "%COMFY_DIR%\models\loras" 2>nul

echo [7/9] Enabling PTX JIT for this session (sm_120 workaround)...
set CUDA_FORCE_PTX_JIT=1

echo [8/9] Quick CUDA kernel test...
python -c "import torch;print('torch',torch.__version__,'cuda?',torch.cuda.is_available(),'cuda',torch.version.cuda);a=torch.randn((1024,1024),device='cuda');b=torch.randn((1024,1024),device='cuda');c=a@b;torch.cuda.synchronize();print('matmul ok, sum=',float(c.sum().cpu()))" || (
  echo   -> GPU カーネル実行に失敗。nightly 更新待ち、または再実行を試してください。
)

echo [9/9] Writing start scripts...
> "%~dp0start_comfy.bat" echo @echo off
>>"%~dp0start_comfy.bat" echo call "%CONDA_BAT%" activate %SD_ENV%
>>"%~dp0start_comfy.bat" echo set CUDA_FORCE_PTX_JIT=1
>>"%~dp0start_comfy.bat" echo "%MINIFORGE%\envs\%SD_ENV%\python.exe" "%COMFY_DIR%\main.py"

> "%~dp0start_comfy_cpu.bat" echo @echo off
>>"%~dp0start_comfy_cpu.bat" echo call "%CONDA_BAT%" activate %SD_ENV%
>>"%~dp0start_comfy_cpu.bat" echo set CUDA_VISIBLE_DEVICES=
>>"%~dp0start_comfy_cpu.bat" echo "%MINIFORGE%\envs\%SD_ENV%\python.exe" "%COMFY_DIR%\main.py"

echo.
echo ==========================================
echo Setup complete!
echo - モデル(.safetensors)を %
