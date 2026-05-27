FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY src/backend/SmartFinance.csproj ./
RUN dotnet restore "SmartFinance.csproj"

COPY src/backend/ ./
RUN dotnet publish "SmartFinance.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:5050

EXPOSE 5050

ENTRYPOINT ["dotnet", "SmartFinance.dll"]
