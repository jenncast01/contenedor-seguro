# Contenedor 2: Servicios Recientes y Seguros (`servidor_seguro`)

## 1. Descripción General y Medidas de Mitigación

Esta imagen está construida sobre **Ubuntu 24.04 LTS** con versiones recientes parcheadas y configuraciones de endurecimiento (*hardening*) aplicadas:

| Servicio | Versión Instalada | Puerto Host | Controles de Seguridad Implementados |
| :--- | :--- | :--- | :--- |
| **Samba (SMB)** | `Samba 4.19.5-Ubuntu` | `2445` / `2139` | Protocolo mínimo y máximo forzado a **SMBv3** (`server min protocol = SMB3`), bloqueo de sesiones anónimas (`restrict anonymous = 2`, `map to guest = Never`), `follow symlinks = no`. |
| **HTTP (Apache)** | `Apache/2.4.58 (Ubuntu)` | `8082` | Ocultamiento de versión (`ServerTokens Prod`, `ServerSignature Off`), deshabilitación de listado de directorios (`Options -Indexes`) y validación estricta de IP con `filter_var($host, FILTER_VALIDATE_IP)` + `escapeshellarg()`. |
| **FTP (vsftpd)** | `vsftpd 3.0.5 (Ubuntu 24.04)` | `2122` | Acceso anónimo deshabilitado (`anonymous_enable=NO`), usuarios locales confinados a su directorio con jaula (`chroot_local_user=YES`) y contraseñas robustas. |

---

## 2. Fase 1: Ejecución de los Mismos Pasos del Contenedor 1 (Entregable Día 2)

Al repetir exactamente los mismos pasos utilizados para vulnerar la primera imagen, todos los vectores de ataque fueron mitigados:

### 2.1. Verificación de Versiones Recientes
```powershell
docker exec servidor_seguro apache2 -v
docker exec servidor_seguro smbd --version
```
* **Resultado:** `Apache/2.4.58 (Ubuntu)` y `Version 4.19.5-Ubuntu`.

---

### 2.2. Repetición de Ataque a HTTP (Banner Grabbing + Directory Listing + Command Injection)

**Comandos ejecutados:**
```powershell
# Intento 1: Obtener versión exacta del servidor en cabeceras HTTP
curl.exe -I http://localhost:8082

# Intento 2: Listar el directorio /backups/
curl.exe -i http://localhost:8082/backups/

# Intento 3: Inyección de comandos con punto y coma (; id; cat /etc/passwd)
curl.exe "http://localhost:8082/index.php?host=127.0.0.1;id;cat+/etc/passwd"
```

**Resultado obtenido (Ataques Bloqueados):**
* La cabecera devuelve únicamente `Server: Apache` sin exponer la versión exacta ni el sistema operativo.
* El acceso a `/backups/` devuelve **`HTTP/1.1 403 Forbidden`**.
* La inyección de comandos es rechazada con el mensaje: **`Bloqueado: Alerta de Seguridad: Direccion IP invalida. Intento de inyeccion de comandos bloqueado.`**

---

### 2.3. Repetición de Ataque a Samba (SMBv1 + Acceso Anónimo)

**Comandos ejecutados:**
```powershell
# Intento 1: Forzar protocolo SMBv1 (NT1) igual que en el contenedor 1
docker exec -it servidor_seguro smbclient -L //localhost -N -m NT1

# Intento 2: Enumerar recursos de forma anónima (-N) sobre SMBv3
docker exec -it servidor_seguro smbclient -L //localhost -N -m SMB3
```

**Resultado obtenido (Ataques Bloqueados):**
* Con `-m NT1`: `Protocol negotiation to server localhost (for a protocol between SMB2_02 and NT1) failed: NT_STATUS_INVALID_PARAMETER_MIX` (SMBv1 rechazado).
* Con `-N -m SMB3`: `tree connect failed: NT_STATUS_ACCESS_DENIED` (sesiones anónimas bloqueadas).

---

### 2.4. Repetición de Ataque a FTP (Login Anónimo + Credenciales Débiles)

**Comandos ejecutados:**
```powershell
# Intento 1: Descarga anónima por FTP
docker exec -it servidor_seguro curl ftp://localhost/pub/credenciales_ftp.txt

# Intento 2: Acceso con las credenciales antiguas (usuario:123456)
docker exec -it servidor_seguro curl -u usuario:123456 ftp://localhost/
```

**Resultado obtenido (Ataques Bloqueados):**
* Ambos intentos son rechazados por el servidor con **`curl: (67) Access denied: 530`**.

---

## 3. Fase 2: Intentos Alternativos por Medios Propios (Entregable Día 2)

Ante el bloqueo de los vectores iniciales, se ejecutaron **4 técnicas alternativas** para intentar vulnerar los servicios:

### Alternativa 1: Evasión de Filtros en Inyección de Comandos HTTP (`|`, `&&`, `%0a`)

**Hipótesis:** Probar si el filtro de inyección de comandos solo bloquea `;` intentando concatenar comandos mediante tuberías (`|`), operador `&&` y saltos de línea codificados (`%0a`).

**Comandos ejecutados:**
```powershell
curl.exe "http://localhost:8082/index.php?host=127.0.0.1|whoami"
curl.exe "http://localhost:8082/index.php?host=127.0.0.1%26%26id"
curl.exe "http://localhost:8082/index.php?host=127.0.0.1%0acat+/etc/passwd"
```

**Resultado:**
* **Mitigado:** Todas las variantes devolvieron `Bloqueado: Alerta de Seguridad: Direccion IP invalida`, ya que el servidor valida estrictamente el formato IP con una lista blanca (`FILTER_VALIDATE_IP`) y `escapeshellarg()`.

---

### Alternativa 2: Subida Directa de WebShell mediante Métodos HTTP (`PUT` y `TRACE`)

**Hipótesis:** Intentar depositar una WebShell directamente en `/uploads/shell.php` utilizando el verbo HTTP `PUT` y probar Cross-Site Tracing con `TRACE`.

**Comandos ejecutados:**
```powershell
curl.exe -i -X PUT -d "<?php system(\$_GET['c']); ?>" http://localhost:8082/uploads/shell.php
curl.exe -i -X TRACE http://localhost:8082/
```

**Resultado:**
* **Mitigado:** El método `PUT` devolvió **`HTTP/1.1 403 Forbidden`** y el método `TRACE` devolvió **`HTTP/1.1 405 Method Not Allowed`**.

---

### Alternativa 3: Ataque de Diccionario por Fuerza Bruta sobre SMBv3

**Hipótesis:** Negociar explícitamente el protocolo moderno **SMBv3** (`-m SMB3`) y ejecutar un ataque de diccionario automatizado con contraseñas comunes contra el recurso `//localhost/privado`.

**Comando ejecutado:**
```powershell
docker exec -it servidor_seguro bash -c 'for pass in 123456 admin password root qwerty; do echo Probando:$pass; smbclient //localhost/privado -U usuario%$pass -m SMB3 -c ls; done'
```

**Resultado:**
* **Mitigado (`session setup failed: NT_STATUS_LOGON_FAILURE`):** Todas las contraseñas del diccionario fueron rechazadas.

---

### Alternativa 4: Intento de Escape de Jaula `chroot` en FTP con Sesión Autenticada

**Hipótesis:** Comprobar si, aun contando con credenciales válidas (`usuario_seguro:S3cur3P@ss2026!`), es posible acceder a `/etc/passwd` mediante la ruta raíz codificada (`%2fetc/passwd`).

**Comando ejecutado:**
```powershell
docker exec -it servidor_seguro curl -u "usuario_seguro:S3cur3P@ss2026!" "ftp://localhost/%2fetc/passwd"
```

**Resultado:**
* **Mitigado (`curl: (9) Server denied you to change to the given directory`):** Gracias a `chroot_local_user=YES`, el usuario queda encerrado dentro de su directorio `/home/usuario_seguro` y el servidor le impide cambiar al directorio `/etc`.
