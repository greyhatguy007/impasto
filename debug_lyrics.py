#!/usr/bin/env python3

import sys
import os

# Add the quickshell directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'home', '.config', 'quickshell'))

# Try to import QML services
try:
    from PyQt5.QtQml import QQmlApplicationEngine
    from PyQt5.QtCore import QObject, QUrl
    
    print("PyQt5 available")
    
    # Create QML engine
    engine = QQmlApplicationEngine()
    
    # Import the QML modules
    engine.rootContext().setContextProperty("pyScriptDir", os.path.join(os.path.dirname(__file__), 'home', '.config', 'quickshell'))
    
    # Load a test QML file that imports our services
    test_qml = '''
    import QtQuick 2.0
    import Quickshell.Services 1.0
    
    Item {
        Component.onCompleted: {
            console.log("MediaService available:", MediaService.available)
            console.log("MediaService title:", MediaService.title)
            console.log("MediaService artist:", MediaService.artist)
            console.log("MediaService length:", MediaService.length)
            
            console.log("LyricsService available:", LyricsService.available)
            console.log("LyricsService loading:", LyricsService.loading)
            console.log("LyricsService track:", LyricsService.track)
            console.log("LyricsService artist:", LyricsService.artist)
            console.log("LyricsService duration:", LyricsService.duration)
            console.log("LyricsService display:", LyricsService.display)
            console.log("LyricsService lines length:", LyricsService.lines.length)
        }
    }
    '''
    
    with open('/tmp/test.qml', 'w') as f:
        f.write(test_qml)
        
    engine.load(QUrl.fromLocalFile('/tmp/test.qml'))
    
    if not engine.rootObjects():
        print("Failed to load QML")
        for error in engine.errors():
            print(error.toString())
    else:
        print("QML loaded successfully")
        
except ImportError as e:
    print(f"PyQt5 not available: {e}")
    
    # Fallback: try to test the Python script directly
    print("\nTesting lyrics script directly:")
    import subprocess
    result = subprocess.run([
        'python3', 
        os.path.join(os.path.dirname(__file__), 'home', '.config', 'quickshell', 'scripts', 'lyrics.py'),
        "We Don't Talk Anymore",
        "Charlie Puth", 
        "Nine Track Mind",
        "217"
    ], capture_output=True, text=True)
    
    print("STDOUT:", result.stdout)
    print("STDERR:", result.stderr)
    print("Return code:", result.returncode)