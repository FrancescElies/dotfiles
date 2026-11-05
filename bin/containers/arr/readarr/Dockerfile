FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
RUN git clone --depth 1 https://github.com/Readarr/Readarr.git . && find . -name '*.csproj' -exec sed -i 's/net6\.0/net8.0/g' {} +
RUN dotnet publish src/NzbDrone.Console/Readarr.Console.csproj -c Release -f net8.0 -o /out
FROM mcr.microsoft.com/dotnet/aspnet:8.0
COPY --from=build /out /app
EXPOSE 8787
CMD ["dotnet", "/app/Readarr.Console.dll"]