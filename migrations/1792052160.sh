#!/bin/bash

# Set a global .NET SDK. The nvim dotnet extra installs csharpier and fantomas
# through `dotnet tool install` and runs omnisharp on the dotnet runtime, so
# both fail outside a project that pins dotnet itself. Project pins still win.
if command -v mise >/dev/null; then
  mise use --global dotnet@10
fi
