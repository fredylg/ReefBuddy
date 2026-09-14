#!/bin/zsh
# Downloads the freely licensed Wikimedia Commons photos used for the demo livestock (see photos/CREDITS.md).
set -e
cd "$(dirname "$0")/photos"
dl(){ curl -sS -L --max-time 40 -A "ReefBuddyPromo/1.0" -o "$1.orig" "$2" && sips -Z 900 -s format jpeg -s formatOptions 82 "$1.orig" --out "$1.jpg" >/dev/null && rm -f "$1.orig" && echo "ok $1"; }
dl acropora "https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Coral_Chimera_Acropora_tenuis.jpg/1280px-Coral_Chimera_Acropora_tenuis.jpg"
dl torch "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Vi_-_Euphyllia_glabrescens_-_1.jpg/1280px-Vi_-_Euphyllia_glabrescens_-_1.jpg"
dl zoa "https://upload.wikimedia.org/wikipedia/commons/2/24/Zoanthus_sansibaricus.jpg"
dl clown "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1f/Amphiprion_ocellaris.001_-_Aquarium_Finisterrae.jpg/1280px-Amphiprion_ocellaris.001_-_Aquarium_Finisterrae.jpg"
dl tang "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Paracanthurus_hepatus_354753703.jpg/1280px-Paracanthurus_hepatus_354753703.jpg"
dl duncan "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Duncanopsammia_axifuga_%28whisker_coral%29.jpg/1280px-Duncanopsammia_axifuga_%28whisker_coral%29.jpg"
dl shrimp "https://upload.wikimedia.org/wikipedia/commons/2/21/Lysmata_amboinensis_269068486.jpg"
dl bta "https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/An%C3%A9mona_burbuja_%28Entacmaea_quadricolor%29%2C_Anilao%2C_Filipinas%2C_2023-08-22%2C_DD_162.jpg/1280px-An%C3%A9mona_burbuja_%28Entacmaea_quadricolor%29%2C_Anilao%2C_Filipinas%2C_2023-08-22%2C_DD_162.jpg"
dl monti "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/Montipora2.jpg/1280px-Montipora2.jpg"
dl clam "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Almeja_gigante_%28Tridacna_maxima%29%2C_Zanz%C3%ADbar%2C_Tanzania%2C_2024-05-30%2C_DD_68.jpg/1280px-Almeja_gigante_%28Tridacna_maxima%29%2C_Zanz%C3%ADbar%2C_Tanzania%2C_2024-05-30%2C_DD_68.jpg"
