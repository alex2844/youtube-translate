# YouTube Translate

> **Translate videos effortlessly.**

This script allows you to easily translate videos from YouTube and other online
platforms. It uses [`vot-cli`](https://github.com/FOSWLY/vot-cli) for
translation and other command-line utilities like [`ffmpeg`](https://ffmpeg.org/)
and [`yt-dlp`](https://github.com/yt-dlp/yt-dlp).

The script is designed to be fast and flexible, working on both local machines
and in Google Colab. It creates universally compatible files (MKV + MP3/AVC)
that work smoothly on Chromecast, Android TV, and Chrome OS.

## Features

* **Automatic translation** of videos from YouTube and other sources.
* **SponsorBlock Integration**: Marks sponsor segments as chapters for automatic
  skipping in players like Kodi and VLC (enabled by default).
* **Media Center Integration**: Automatically generates `.nfo` metadata and
  thumbnail files, perfect for Kodi, Jellyfin, and Emby.
* **High performance**: Optimized specifically for speed using MKV container
  and MP3 audio (no heavy transcoding).
* **Playlist support**: Can process entire YouTube playlists automatically.
* **Smart Organization**: Optional numbering for playlist files
  (`01 - Video...`).
* **YouTube Sync**: Can mark videos as "watched" on YouTube (requires cookies).
* **Local file support**: Use an existing video file to save bandwidth, while
  fetching the translation using the URL.
* **Broad compatibility**: Resulting files work well on Chromecast, Pixelbook,
  and Kodi. Includes an option to force H.264 (AVC) for older devices.
* **Configuration**: Support for `.env` files, settings saving (Colab), and
  flexible flags.

## Usage

### Local

1. Install the necessary dependencies (ffmpeg, yt-dlp, vot-cli, npm/pip).
2. Make [`ytranslate.sh`](https://raw.githubusercontent.com/alex2844/youtube-translate/main/ytranslate.sh)
   executable: `chmod +x ytranslate.sh`.
3. (Optional) Create a `.env` file to store your preferences (e.g.,
   `YT_TOLANG=ru`).
4. Run the script:

    ```bash
    ./ytranslate.sh [OPTIONS] <URL> [LOCAL_FILE]
    ```

    **Options:**

    * `-h, --help`: Show help message.
    * `-v, --version`: Show script version.
    * `-r, --height=<int>`: Set max video height (e.g., 1080). Default: Best.
    * `-f, --from_lang=<str>`: Set source language (default: en).
    * `-t, --to_lang=<str>`: Set target language (default: ru).
    * `-o, --output=<path>`: Set output directory.
    * `-c, --cookies=<path>`: Path to cookies file (for private playlists or
      marking watched).
    * `-4, --ipv4`: Force IPv4 connection.
    * `--force-avc`: Force AVC (H.264) video codec. Useful for older TVs.
    * `--mark-watched`: Mark video as watched on YouTube (requires cookies).
    * `--add-index`: Add playlist index to filenames (e.g., "01 - Title.mkv").
    * `--meta`: Generate NFO and JPG for Media Centers.
    * `--no-sponsorblock`: Disable marking sponsor segments (enabled by default).
    * `--no-cleanup`: Keep temporary files.

    **Examples:**

    Translate a single YouTube video:

    ```bash
    ./ytranslate.sh -f en -t ru -r 1080 https://youtu.be/VIDEO_ID
    ```

    Translate a playlist, creating metadata, numbering files, and marking as
    watched:

    ```bash
    ./ytranslate.sh -c cookies.txt --add-index --meta --mark-watched \
      https://www.youtube.com/playlist?list=WL
    ```

    Use a local video file (avoids redownloading) + URL for translation source:

    ```bash
    ./ytranslate.sh https://youtu.be/VIDEO_ID /path/to/downloaded_video.mp4
    ```

### Google Colab

1. Open the [`ytranslate.ipynb`](https://colab.research.google.com/github/alex2844/youtube-translate/blob/main/ytranslate.ipynb)
   file in Google Colab.
2. Fill in the parameters in the "Settings" block. You can enable options
   like `FORCE_AVC`, `MARK_WATCHED`, and `ADD_INDEX` via checkboxes.
3. Run all cells.
4. The script will process the video(s) and save them to your Google Drive
   or prompt for download.

## Installing Dependencies

If you don't have dependencies installed locally, you can use the
`INSTALL_DEPENDENCIES=true` variable to attempt auto-installation.

```bash
INSTALL_DEPENDENCIES=true ./ytranslate.sh [OPTIONS] <URL>
```

**Note:** Root (sudo) permissions are required for auto-installation.

---

### Переводите видео без усилий

Этот скрипт позволяет легко переводить видео с YouTube и других онлайн-платформ.
Он использует [`vot-cli`](https://github.com/FOSWLY/vot-cli) для перевода, а
также утилиты командной строки [`ffmpeg`](https://ffmpeg.org/) и
[`yt-dlp`](https://github.com/yt-dlp/yt-dlp).

Скрипт оптимизирован для высокой скорости и создает файлы (MKV + MP3/AVC),
которые корректно воспроизводятся на большинстве устройств, включая Chromecast,
Android TV и Chrome OS.

## Возможности

* **Автоматический перевод** видео с YouTube и других источников.
* **Интеграция со SponsorBlock**: Создает в MKV-файле главы для
  автоматического пропуска спонсорских сегментов (включено по умолчанию).
* **Интеграция с медиацентрами**: Автоматическое создание метаданных (`.nfo`)
  и обложек, идеально для Kodi, Jellyfin и Emby.
* **Высокая скорость**: Использование контейнера MKV и аудио MP3 позволяет
  избежать долгого перекодирования.
* **Поддержка плейлистов**: Возможность обработки целых плейлистов YouTube.
* **Умная организация**: Опциональная нумерация файлов плейлиста
  (`01 - Видео...`).
* **Синхронизация с YouTube**: Возможность помечать видео как "просмотренные"
  (нужны cookies).
* **Поддержка локальных файлов**: Использование уже скачанного файла для
  экономии трафика, пока перевод загружается по ссылке.
* **Совместимость**: Файлы оптимизированы для Chromecast и Kodi. Опция
  принудительного кодека H.264 (AVC) для старых устройств.
* **Гибкая настройка**: Поддержка `.env` файлов, сохранение настроек (Colab)
  и множество флагов запуска.

## Использование

### Локально

1. Установите необходимые зависимости (ffmpeg, yt-dlp, vot-cli, npm/pip).
2. Сделайте [`ytranslate.sh`](https://raw.githubusercontent.com/alex2844/youtube-translate/main/ytranslate.sh)
   исполняемым: `chmod +x ytranslate.sh`.
3. (Опционально) Создайте файл `.env` для сохранения настроек (например,
   `YT_TOLANG=ru`).
4. Запустите скрипт:

    ```bash
    ./ytranslate.sh [ОПЦИИ] <URL> [ЛОКАЛЬНЫЙ_ФАЙЛ]
    ```

    **Опции:**

    * `-h, --help`: Показать справку.
    * `-v, --version`: Показать версию скрипта.
    * `-r, --height=<int>`: Макс. высота видео (напр. 1080).
    * `-f, --from_lang=<str>`: Язык оригинала (по умолчанию: en).
    * `-t, --to_lang=<str>`: Язык перевода (по умолчанию: ru).
    * `-o, --output=<path>`: Папка для сохранения.
    * `-c, --cookies=<path>`: Путь к cookies (для приватных плейлистов или
      пометки "Просмотрено").
    * `-4, --ipv4`: Принудительно использовать IPv4.
    * `--force-avc`: Принудительно использовать кодек AVC (H.264).
    * `--mark-watched`: Помечать видео как просмотренное на YouTube.
    * `--add-index`: Добавлять порядковый номер плейлиста в имя файла.
    * `--meta`: Создавать метаданные (.nfo и .jpg) для медиацентров.
    * `--no-sponsorblock`: Отключить разметку спонсорских сегментов (включено
      по умолчанию).
    * `--no-cleanup`: Не удалять временные файлы.

    **Примеры:**

    Перевод одного видео:

    ```bash
    ./ytranslate.sh -f en -t ru -r 1080 https://youtu.be/VIDEO_ID
    ```

    Перевод плейлиста с метаданными, нумерацией и пометкой "просмотрено":

    ```bash
    ./ytranslate.sh -c cookies.txt --add-index --meta --mark-watched \
      https://www.youtube.com/playlist?list=WL
    ```

    Использование локального файла (чтобы не качать) + URL для перевода:

    ```bash
    ./ytranslate.sh https://youtu.be/VIDEO_ID /path/to/my_video.mp4
    ```

### Запуск в Google Colab

1. Откройте файл [`ytranslate.ipynb`](https://colab.research.google.com/github/alex2844/youtube-translate/blob/main/ytranslate.ipynb)
   в Google Colab.
2. Заполните параметры в блоке "Settings". Вы можете включить `FORCE_AVC`,
   `MARK_WATCHED` и `ADD_INDEX` через чекбоксы.
3. Запустите все ячейки.
4. Скрипт обработает видео и автоматически сохранит их на Google Drive или
   предложит скачать.

## Установка Зависимостей

Если зависимости не установлены, можно использовать переменную
`INSTALL_DEPENDENCIES=true` для их автоматической установки.

```bash
INSTALL_DEPENDENCIES=true ./ytranslate.sh [ОПЦИИ] <URL>
```

**Примечание:** Для автоматической установки требуются права суперпользователя
(root).

---

## Youtube

| [![google][google_img]][google_url] | [![linux][linux_img]][linux_url]
| --- | ---

[google_img]: https://img.youtube.com/vi/7-rYQ2QHXgo/0.jpg "Google Colab"
[google_url]: https://youtu.be/7-rYQ2QHXgo
[linux_img]: https://img.youtube.com/vi/gNvPf7nGXFQ/0.jpg "Linux"
[linux_url]: https://youtu.be/gNvPf7nGXFQ
