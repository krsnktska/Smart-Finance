FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY src/backend/SmartFinance.csproj ./
RUN dotnet restore "SmartFinance.csproj"

COPY src/backend/ ./
RUN dotnet publish "SmartFinance.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    libtesseract-dev \
    libleptonica-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/publish .

RUN mkdir -p /app/x64 && \
    ln -sf /usr/lib/x86_64-linux-gnu/liblept.so /app/x64/libleptonica-1.82.0.so && \
    ln -sf /usr/lib/x86_64-linux-gnu/libtesseract.so /app/x64/libtesseract50.so

ENV ASPNETCORE_URLS=http://+:5050

EXPOSE 5050

ENTRYPOINT ["dotnet", "SmartFinance.dll"]
