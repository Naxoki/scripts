# MAMP Control Panel

Script para Windows que permite alternar rápidamente entre proyectos **personales** y **laborales** en MAMP, y cambiar la versión de PHP desde la terminal.

## ¿Qué hace?

- **Modo Personal / Laboral**: cambia el `Document Root` de MAMP entre dos carpetas de proyectos usando [junctions](https://learn.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions) (symlinks de carpetas en Windows).
- **Cambio de versión de PHP**: oculta las versiones superiores a la elegida renombrándolas con sufijo `_X`, para que MAMP solo vea la versión que necesitás.
- **Inicio automático de MAMP**: si MAMP no está corriendo, lo inicia. Si necesita reiniciar por cambio de PHP, lo hace automáticamente.
- **Selección automática de PHP en MAMP**: usa una secuencia de teclas (`SendKeys`) para navegar las Preferences de MAMP y seleccionar la versión correcta sin intervención manual.

## Requisitos

- Windows 10/11
- [MAMP](https://www.mamp.info/en/windows/) instalado en `C:\MAMP`
- PowerShell 5.1 o superior (incluido en Windows 10/11)
- Permisos de Administrador (el `.bat` se auto-eleva)

## Estructura de carpetas

Antes de usar el script, creá la siguiente estructura:

```
D:\
├── htdocs\
│   ├── personal\        ← tus proyectos personales
│   │   ├── mi-blog\
│   │   └── portfolio\
│   └── laboral\         ← tus proyectos de trabajo
│       ├── cliente-abc\
│       └── sistema-interno\
│
└── scripts\
    ├── switch-mamp.bat  ← ejecutar este archivo
    └── switch-mode.ps1  ← script principal
```

## Instalación paso a paso

### 1. Crear las carpetas de proyectos

```
mkdir D:\htdocs\personal
mkdir D:\htdocs\laboral
```

Mové tus proyectos personales a `D:\htdocs\personal\` y los laborales a `D:\htdocs\laboral\`.

### 2. Crear la carpeta de scripts

```
mkdir D:\scripts
```

Copiá `switch-mamp.bat` y `switch-mode.ps1` dentro de `D:\scripts\`.

### 3. Preparar MAMP (primera ejecución)

La primera vez que ejecutes el script, este **automáticamente**:

1. Renombra `C:\MAMP\htdocs` a `C:\MAMP\htdocs_original` (backup de la carpeta original).
2. Crea un junction `C:\MAMP\htdocs` que apunta a `D:\htdocs\personal` o `D:\htdocs\laboral` según elijas.

> **Importante**: no necesitás cambiar el Document Root en MAMP manualmente. El script reemplaza la carpeta `htdocs` directamente, así MAMP cree que sigue usando su carpeta de siempre.

### 4. Ejecutar

Doble click en `switch-mamp.bat`. Se abrirá una ventana de Administrador y verás:

```
  ==========================================
       MAMP Control Panel
  ==========================================

  Estado MAMP:    CORRIENDO (Apache + MySQL)
  Modo actual:    PERSONAL
  PHP max visible:php8.3.0

  --- Modo de trabajo ---
  [1] Personal
  [2] Laboral
  [0] Salir

  Elige modo: _
```

## Cómo funciona el cambio de PHP

MAMP solo muestra las **2 versiones de PHP más recientes** que encuentra en `C:\MAMP\bin\php\`. El script aprovecha esto renombrando las versiones superiores a la elegida con un sufijo `_X` al final del nombre.

### Ejemplo

Si tenés estas versiones instaladas y elegís `php7.4.16`:

```
C:\MAMP\bin\php\
├── php5.5.38          ← intacta (inferior)
├── php5.6.34          ← intacta (inferior)
├── php7.2.18          ← intacta (inferior)
├── php7.3.19          ← intacta (inferior)
├── php7.4.16          ← la más alta visible → MAMP la usa
├── php8.3.0_X         ← renombrada (superior, oculta para MAMP)
└── sessions           ← no se toca
```

### Reglas importantes

- Las versiones **inferiores** a la elegida **nunca se renombran** (MAMP las necesita como dependencias).
- Las versiones **superiores** se renombran agregando `_X` al final.
- Al elegir una versión más alta, las renombradas se restauran automáticamente (se quita el `_X`).

### Selección automática en MAMP

Después de renombrar las carpetas y reiniciar MAMP, el script ejecuta una secuencia automática de teclas para navegar las Preferences de MAMP y seleccionar la versión de PHP:

> **No toques el teclado ni el mouse** durante los ~5 segundos que dura este proceso.

La secuencia es: `TAB` → `ENTER` ×2 → `CTRL+TAB` ×3 → `DOWN` ×2 → `TAB` ×2 → `ENTER` → minimizar ventana.

## Configuración personalizada

Si tu instalación de MAMP o tus carpetas están en rutas diferentes, editá las variables al inicio de `switch-mode.ps1`:

```powershell
$MampHtdocs    = "C:\MAMP\htdocs"          # Carpeta htdocs de MAMP
$MampHtdocsBak = "C:\MAMP\htdocs_original" # Backup de htdocs original
$PersonalPath  = "D:\htdocs\personal"       # Carpeta de proyectos personales
$LaboralPath   = "D:\htdocs\laboral"        # Carpeta de proyectos laborales
$MampExe       = "C:\MAMP\MAMP.exe"        # Ejecutable de MAMP
$PhpBaseDir    = "C:\MAMP\bin\php"          # Carpeta de versiones de PHP
```

Si guardaste los scripts en otra ruta, editá `switch-mamp.bat`:

```batch
powershell -ExecutionPolicy Bypass -File "TU_RUTA\switch-mode.ps1"
```

## Archivos

| Archivo | Descripción |
|---|---|
| `switch-mamp.bat` | Launcher. Auto-eleva a Administrador y ejecuta el script de PowerShell. |
| `switch-mode.ps1` | Script principal con toda la lógica. |

## Solución de problemas

**MAMP se cierra al cambiar PHP**
Asegurate de que todas las carpetas de PHP en `C:\MAMP\bin\php\` estén presentes (las inferiores sin renombrar). MAMP necesita que las versiones inferiores existan como dependencias.

**El script dice "No es junction"**
Si `C:\MAMP\htdocs` es una carpeta real (no un junction), el script necesita hacer el backup inicial. Asegurate de que no exista ya `C:\MAMP\htdocs_original`. Si existe, eliminala o renombrala manualmente.

**La secuencia de teclas no funciona correctamente**
Los tiempos de espera (`Start-Sleep`) entre teclas pueden necesitar ajuste según la velocidad de tu equipo. Editá los valores de `Start-Sleep -Milliseconds` en la sección de `SendKeys` del script.

**"Este script requiere permisos de Administrador"**
El `.bat` debería auto-elevarse. Si no funciona, hacé click derecho en `switch-mamp.bat` → Ejecutar como Administrador.

## Limitaciones

- La selección automática de PHP usa `SendKeys`, que requiere que la ventana de MAMP esté en primer plano. No toques nada durante el proceso.
- MAMP siempre muestra solo 2 versiones de PHP en Preferences. Esto es una limitación de MAMP, no del script.
- Probado con MAMP 5.0.5 en Windows. Otras versiones pueden tener diferencias en la interfaz que afecten la secuencia de teclas.

## Licencia

MIT
