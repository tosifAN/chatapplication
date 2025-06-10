@echo off
echo Running build_runner...
flutter pub run build_runner build --delete-conflicting-outputs
pause
