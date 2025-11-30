# Multi-stage build for .NET application
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY *.csproj ./
RUN dotnet restore

# Copy everything else and build
COPY . ./
RUN dotnet publish -c Release -o /app/publish

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Copy published app
COPY --from=build /app/publish .

# Create non-root user
RUN useradd -m -u 1001 dotnet && \
    chown -R dotnet:dotnet /app

USER dotnet

EXPOSE 8080

ENTRYPOINT ["dotnet", "app.dll"]
