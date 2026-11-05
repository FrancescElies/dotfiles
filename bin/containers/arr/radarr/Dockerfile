FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
RUN git clone --depth 1 https://github.com/Radarr/Radarr.git . && find . -name '*.csproj' -exec sed -i 's/net6\.0/net8.0/g' {} +
RUN rm -rf /src/_temp/obj && dotnet publish src/NzbDrone.Console/Radarr.Console.csproj -c Release -f net8.0 -o /out -p:NuGetAudit=false -p:TreatWarningsAsErrors=false
FROM mcr.microsoft.com/dotnet/aspnet:8.0
COPY --from=build /out /app
EXPOSE 7878
CMD ["dotnet", "/app/Radarr.Console.dll"]