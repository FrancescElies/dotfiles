FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
RUN git clone --depth 1 https://github.com/Lidarr/Lidarr.git . && find . -name '*.csproj' -exec sed -i 's/net6\.0/net8.0/g' {} +
RUN dotnet publish src/NzbDrone.Console/Lidarr.Console.csproj -c Release -f net8.0 -o /out
FROM mcr.microsoft.com/dotnet/aspnet:8.0
COPY --from=build /out /app
EXPOSE 8686
CMD ["dotnet", "/app/Lidarr.Console.dll"]