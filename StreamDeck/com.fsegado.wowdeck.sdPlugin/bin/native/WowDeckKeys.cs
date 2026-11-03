// ---------------------------------------------------------------------------
// WowDeckKeys - pulsaciones de teclado simuladas
//
// helper.ps1 compila este archivo al arrancar (Add-Type). Está separado del
// script para poder reutilizarlo y probarlo por su cuenta.
// ---------------------------------------------------------------------------
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

public static class WowDeckKeys {
    // keybd_event inyecta la pulsación en la cola de entrada de Windows, como
    // si viniera del teclado físico, y la recibe la ventana que tenga el foco.
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);

    // Traduce un código VK a su código de exploración (scan code). Algunos
    // juegos leen el scan code y no el VK, así que enviamos los dos.
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint mapType);

    // Estado actual de una tecla en todo el sistema, no solo en esta ventana.
    // El bit más alto indica si está pulsada ahora mismo.
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);

    const uint KEYUP = 2;
    const int DOWN_BIT = 0x8000;

    static void Send(byte vk, uint flags) {
        keybd_event(vk, (byte)MapVirtualKey(vk, 0), flags, UIntPtr.Zero);
    }

    public static bool IsDown(byte vk) {
        return (GetAsyncKeyState(vk) & DOWN_BIT) != 0;
    }

    // Teclas que hay que pulsar de verdad. Todas menos la última son
    // modificadores (Ctrl, Alt, Mayús): si el jugador ya mantiene alguno con la
    // mano, no lo tocamos. Si lo pulsáramos y soltáramos nosotros, el juego
    // creería que lo ha soltado aunque lo siga manteniendo. La última tecla
    // (la F) se pulsa siempre.
    public static List<byte> KeysToPress(byte[] vks) {
        var keys = new List<byte>();
        for (int i = 0; i < vks.Length; i++) {
            bool isModifier = i < vks.Length - 1;
            if (isModifier && IsDown(vks[i])) continue;
            keys.Add(vks[i]);
        }
        return keys;
    }

    // Pulsa la combinación y suelta en orden inverso solo lo que pulsó.
    public static void Press(byte[] vks, int holdMs) {
        var keys = KeysToPress(vks);
        foreach (var vk in keys) Send(vk, 0);
        // Una pulsación de 0 ms puede no registrarse en un juego que lee el
        // teclado una vez por fotograma: mantenemos la tecla un momento.
        Thread.Sleep(holdMs);
        for (int i = keys.Count - 1; i >= 0; i--) Send(keys[i], KEYUP);
    }

    // Solo para pruebas: deja una tecla pulsada o la suelta.
    public static void Down(byte vk) { Send(vk, 0); }
    public static void Up(byte vk) { Send(vk, KEYUP); }
}
