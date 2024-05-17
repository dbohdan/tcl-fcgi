# Install Tcl.
choco install magicsplat-tcl-tk --version 1.14 --yes

# Download and extract Nginx.
Invoke-WebRequest -OutFile nginx.zip https://nginx.org/download/nginx-1.26.0.zip
Expand-Archive -Path nginx.zip -DestinationPath .
New-Item -ItemType SymbolicLink -Path nginx.exe -Target .\nginx-1.26.0\nginx.exe
