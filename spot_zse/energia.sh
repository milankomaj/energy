# ==============================================================================
# 1. OFICIÁLNE REÁLNE VSTUPY A LEGISLATIVNE PARAMETRE SR (Rok 2026)
# ==============================================================================
# Zdroj OKTE, a.s. – Krátkodobý vnútrodenný a denný trh s elektrickou energiou.
# Oficiálny odkaz: https://okte.sk
DATUM=$(date -d "+1 day" +%Y-%m-%d)   #$(date +%Y-%m-%d)    # $(date -d "+1 day" +%Y-%m-%d)

# VSTUPY: Užívateľské parametre odberného miesta domácnosti.
SPOTREBA_KWH=600
POCET_DNI=365

ISTIC_AMPER=15
ISTIC_FAZY=1

# Sadzby DPH schválené v Konsolidačnom balíčku SR pre rok 2025/2026.
# Zdroj: Ministerstvo financií SR (Zákon č. 222/2004 Z. z. o dani z pridanej hodnoty).
DPH_OBCHOD=19                # 19% znížená sadzba DPH na dodávku silovej elektriny
DPH_SIET=23                  # 23% základná sadzba DPH na distribúciu a sieťové služby

# CENNÍKOVÉ VSTUPY DODÁVATEĽA: Produktový rad DomovKlasik (Sadzba DD2).
# Zdroj: ZSE Energia, a. s. (Cenník elektriny pre domácnosti / Memorandum so SE).
MAM_EP=true                  # Uplatnenie štátnej adresnej Energopomoci (Garantovaná cena vlády)
SIL_EP_BEZ=0.061200          # SKUTOČNÁ vládna zastropovaná cena komodity pre rok 2026
SIL_STANDARD_BEZ=0.123300    # Štandardná cenníková maximálna cena bez vládnej dotácie
FIX_DODAVKA_BEZ=1.500000     # Mesačná platba obchodníkovi za odberné miesto

# CENNÍKOVÉ VSTUPY DISTRIBÚTORA: Sieťové poplatky pre územie ZSDIS (Sadzba DD2).
# Zdroj: Cenové rozhodnutia ÚRSO č. 0077/2026/E, 0113/2026/E a 0067/2026/E.
DIST_VAR_BEZ=0.025939        # REÁLNA 2026: Tarifa za distribúciu vrátane prenosu
STRATY_BEZ=0.010468          # REÁLNA 2026: Tarifa za straty v distribučnej sústave
TPS_BEZ=0.014071             # REÁLNA 2026: Tarifa za prevádzkovanie systému (OKTE pásmo 1)
TSS_BEZ=0.010980             # REÁLNA 2026: Tarifa za systémové služby (SEPS)

# Odvod do Národného jadrového fondu (NJF) oslobodený od DPH (0% sadzba).
# Zdroj: Slovenská legislatíva (Zákon č. 308/2018 Z. z. o Národnom jadrovom fondu).
NJF_BEZ=0.003270

# Fixné sieťové paušály za odberné miesto a ampérovú kapacitu (ZSDIS r. 2026).
FIX_DISTRIB_BEZ=0.750000     # Mesačný paušál distribútorovi za odberné miesto
CENA_ISTIC_1F_BEZ=0.220200   # REÁLNA 2026: Platba za 1 Ampér (Rozhodnutie ÚRSO pre ZSD)
CENA_ISTIC_3F_BEZ=0.660600   # REÁLNA 2026: Platba za 1 Ampér pre trojfázové pripojenie

# KOEFICIENT CENY (K): Obchodná prirážka pre nákupnú Dynamickú tarifu.
KOEFICIENT_K_ZSE=1.080000

# MARŽA VÝKUPU: Poplatok obchodníka za manažment prebytkov (EUR/kWh bez DPH).
PRIRAZKA_VYKUP_BEZ=0.012000

# CLOUDFLARE AI CONFIGURATION
CLOUDFLARE_ACCOUNT_ID=$(echo $CLOUDFLARE_ACCOUNT_ID)
CLOUDFLARE_EMAIL=$(echo $CLOUDFLARE_EMAIL)
CLOUDFLARE_API_TOKEN=$(echo $CLOUDFLARE_API_TOKEN)



# Globálne vynútenie bodkového desatinného formátu pre matematický procesor bc
export LC_NUMERIC=C


# ==============================================================================
# 2. AUTOMATICKÝ VÝPOČET VARIABILNEJ DISTRIBÚCIE (ZSDIS r. 2026)
# ==============================================================================
DIST_PODLIEHA_DPH_BEZ=$(echo "scale=6; $DIST_VAR_BEZ + $STRATY_BEZ + $TPS_BEZ + $TSS_BEZ" | bc -l)
DIST_TOTAL=$(echo "scale=6; $DIST_PODLIEHA_DPH_BEZ + $NJF_BEZ" | bc -l)

# ==============================================================================
# 3. AUTOMATICKÝ VÝPOČET FIXNÝCH PAUŠÁLOV A OŠETRENIE NULOVÉHO ODBERU
# ==============================================================================
if [ "$ISTIC_FAZY" -eq 1 ]; then
    FIX_ISTIC_BEZ_DPH=$(echo "scale=6; $ISTIC_AMPER * $CENA_ISTIC_1F_BEZ" | bc -l)
else
    FIX_ISTIC_BEZ_DPH=$(echo "scale=6; $ISTIC_AMPER * $CENA_ISTIC_3F_BEZ" | bc -l)
fi

BEZPECNA_SPOTREBA=$SPOTREBA_KWH
if [ "$(echo "$SPOTREBA_KWH == 0" | bc -l)" -eq 1 ]; then
    BEZPECNA_SPOTREBA="0.000001"
fi

DEN_FIX_OBCHOD_BEZ=$(echo "scale=6; ($FIX_DODAVKA_BEZ * 12) / $POCET_DNI" | bc -l)
DEN_FIX_SIET_BEZ=$(echo "scale=6; (($FIX_DISTRIB_BEZ + $FIX_ISTIC_BEZ_DPH) * 12) / $POCET_DNI" | bc -l)

# ==============================================================================
# 4. AUTOMATICKÉ PRIRADENIE SILOVEJ ELEKTRINY PODĽA STATUSU ENERGOPOMOCI
# ==============================================================================
if [ "$MAM_EP" = true ]; then
    SIL_BEZ=$SIL_EP_BEZ
else
    SIL_BEZ=$SIL_STANDARD_BEZ
fi

TOTAL_OBCHOD_BEZ=$(echo "scale=6; ($SPOTREBA_KWH * $SIL_BEZ) + ($POCET_DNI * $DEN_FIX_OBCHOD_BEZ)" | bc -l)
TOTAL_DISTRIB_BEZ=$(echo "scale=6; ($SPOTREBA_KWH * $DIST_TOTAL) + ($POCET_DNI * $DEN_FIX_SIET_BEZ)" | bc -l)

TOTAL_DPH_19=$(echo "scale=6; $TOTAL_OBCHOD_BEZ * ($DPH_OBCHOD / 100)" | bc -l)
TOTAL_DISTRIB_ZDANITELNA_BEZ=$(echo "scale=6; ($SPOTREBA_KWH * $DIST_PODLIEHA_DPH_BEZ) + ($POCET_DNI * $DEN_FIX_SIET_BEZ)" | bc -l)
TOTAL_DPH_23=$(echo "scale=6; $TOTAL_DISTRIB_ZDANITELNA_BEZ * ($DPH_SIET / 100)" | bc -l)

ZAKLAD_SPOLU=$(echo "scale=6; $TOTAL_OBCHOD_BEZ + $TOTAL_DISTRIB_BEZ" | bc -l)
DPH_SPOLU=$(echo "scale=6; $TOTAL_DPH_19 + $TOTAL_DPH_23" | bc -l)
FAKTURA_S_DPH=$(echo "scale=6; $ZAKLAD_SPOLU + $DPH_SPOLU" | bc -l)

# ==============================================================================
# 5. SPÄTNÉ MAPOVANIE PRE KONEČNÝ JQ FILTER (Dátové rozhranie pre Časť 6)
# ==============================================================================
CENA_ZSE=$(echo "scale=6; $FAKTURA_S_DPH / $BEZPECNA_SPOTREBA" | bc -l)
SIL_DPH=$(echo "scale=6; $SIL_BEZ * (1 + ($DPH_OBCHOD / 100))" | bc -l)

DIST_TOTAL=$(echo "scale=6; $DIST_PODLIEHA_DPH_BEZ" | bc -l)
NJF_EXTRA_BEZ=$NJF_BEZ

PAUSAL_BEZ_DPH=$(echo "scale=6; (($POCET_DNI * $DEN_FIX_OBCHOD_BEZ) + ($POCET_DNI * $DEN_FIX_SIET_BEZ)) / 12" | bc -l)
PAUSAL_S_DPH=$(echo "scale=6; (($POCET_DNI * $DEN_FIX_OBCHOD_BEZ * (1 + ($DPH_OBCHOD / 100))) + ($POCET_DNI * $DEN_FIX_SIET_BEZ * (1 + ($DPH_SIET / 100)))) / 12" | bc -l)

if [ "$(echo "$ZAKLAD_SPOLU == 0" | bc -l)" -eq 1 ]; then
    DPH_PCT="23.00"
else
    DPH_PCT=$(echo "scale=2; ($DPH_SPOLU / $ZAKLAD_SPOLU) * 100" | bc -l)
fi

# ==============================================================================
# 6. DOPYT NA API OKTE A TVORBA PREČISTENÉHO JSON VÝSTUPU S IMUNITOU VOČI SPOTREBE
# ==============================================================================
RAW_API_ODPOVED=$(curl -s -X GET "https://isot.okte.sk/api/v1/dam/results?deliveryDayFrom=${DATUM}&deliveryDayTo=${DATUM}" -H "accept: application/json")

MOJ_VYSTUP_JSON=$(echo "$RAW_API_ODPOVED" | jq \
  --arg dist "$DIST_TOTAL" --arg zse_tot "$CENA_ZSE" --arg sb "$SIL_BEZ" --arg sd "$SIL_DPH" \
  --arg pb "$PAUSAL_BEZ_DPH" --arg pd "$PAUSAL_S_DPH" --arg datum "$DATUM" --arg ep "$MAM_EP" --arg dph "$DPH_PCT" \
  --arg amper "$ISTIC_AMPER" --arg fazy "$ISTIC_FAZY" --arg koef "$KOEFICIENT_K_ZSE" --arg dph_siet "$DPH_SIET" \
  --arg dph_obchod "$DPH_OBCHOD" --arg njf "$NJF_EXTRA_BEZ" --arg v_marza "$PRIRAZKA_VYKUP_BEZ" \
  --arg den_fix_obchod "$DEN_FIX_OBCHOD_BEZ" --arg den_fix_siet "$DEN_FIX_SIET_BEZ" '

  ($dist | tonumber) as $dist_kwh_zdanitelna |
  ($njf | tonumber) as $njf_kwh_oslobodena |
  ($sb | tonumber) as $zse_sil_bez |
  ($koef | tonumber) as $k_zse |
  ($v_marza | tonumber) as $v_marza_kwh |
  (($dph_siet | tonumber) / 100 + 1) as $siet_koef |
  (($dph_obchod | tonumber) / 100 + 1) as $obchod_koef |
  ($pb | tonumber) as $p_bez |
  ($pd | tonumber) as $p_dph |
  ($ep == "true") as $is_ep |
  ($amper | tonumber) as $i_amp |
  ($fazy | tonumber) as $i_faz |

  ((($den_fix_obchod | tonumber) * $obchod_koef + ($den_fix_siet | tonumber) * $siet_koef) / 24) as $hodinovy_fix_s_dph |
  (($zse_sil_bez * $obchod_koef) + ($dist_kwh_zdanitelna * $siet_koef) + $njf_kwh_oslobodena) as $zse_koncova_cena_kwh_s_dph |

  ($dist_kwh_zdanitelna + $njf_kwh_oslobodena) as $dist_total_kontext |
  (if type == "object" then .data or .parts or . else . end) as $raw_data |
  (($raw_data | type == "array") and ($raw_data | length > 0)) as $mame_sietove_data |

  [ range(0; 24) as $h |
    [ $raw_data[$h*4 : $h*4+4][].price | select(. != null) ] as $stvrt_hodiny_ceny |

    (if $mame_sietove_data then
      (if ($stvrt_hodiny_ceny | length) == 0 then 0 else ($stvrt_hodiny_ceny | add / length) end / 1000)
     else
      null
     end) as $spot_bez |

    (if $spot_bez != null then ((($spot_bez * $k_zse) * $obchod_koef) + ($dist_kwh_zdanitelna * $siet_koef) + $njf_kwh_oslobodena) else null end) as $spot_koncova_kwh_s_dph |
    (if $spot_bez != null then (($spot_bez - $v_marza_kwh)) else null end) as $vykup_total |

    {
      "hodina": ((if $h < 10 then "0" + ($h | tostring) else ($h | tostring) end) + ":00 - " + (if ($h+1) < 10 then "0" + (($h+1) | tostring) else (($h+1) | tostring) end) + ":00"),
      "spot_cena_burza_kwh_bez_dph": (if $spot_bez != null then ($spot_bez * 1000000 | round / 1000000) else null end),
      "spot_spolu_koncova_cena_s_dph": (if $spot_koncova_kwh_s_dph != null then (($spot_koncova_kwh_s_dph + $hodinovy_fix_s_dph) * 1000000 | round / 1000000) else null end),
      "vykup_cena_kwh_bez_dph": (if $vykup_total != null then ($vykup_total * 1000000 | round / 1000000) else null end),
      "zse_spolu_koncova_cena_s_dph": (($zse_koncova_cena_kwh_s_dph + $hodinovy_fix_s_dph) * 1000000 | round / 1000000),
      "vyhodnost_spotu": (if $spot_koncova_kwh_s_dph != null then ((($zse_koncova_cena_kwh_s_dph - $spot_koncova_kwh_s_dph) * 1000000 | round) / 1000000) else null end)
    }
  ] as $hodiny |

  ([ $hodiny[].spot_spolu_koncova_cena_s_dph | select(. != null) ]) as $validne_spoty |
  (if ($validne_spoty | length) > 0 then ($validne_spoty | add) / ($validne_spoty | length) else null end) as $priemer_spot_s_dph |

  ($hodiny | sort_by(.spot_spolu_koncova_cena_s_dph)) as $zoradene_hodiny |

  ($zoradene_hodiny[0].hodina) as $min_cas |
  ($zoradene_hodiny[0].spot_spolu_koncova_cena_s_dph) as $min_cena |
  ($zoradene_hodiny[-1].hodina) as $max_cas |
  ($zoradene_hodiny[-1].spot_spolu_koncova_cena_s_dph) as $max_cena |

  ([ $hodiny[].vyhodnost_spotu | select(. != null) ]) as $validne_vyhodnosti |
  (if ($validne_vyhodnosti | length) > 0 then ($validne_vyhodnosti | add) / ($validne_vyhodnosti | length) else null end) as $priemerna_vyhodnost |

($hodiny | map(select(.vyhodnost_spotu != null and .vyhodnost_spotu > 0) | .hodina)) as $plusove_pol |
($hodiny | map(select(.vyhodnost_spotu != null and .vyhodnost_spotu < 0) | .hodina)) as $minusove_pol |
{
"kontext": {
"datum": $datum,
"api_status": (if $mame_sietove_data then "ONLINE_OK" else "OFFLINE_ERR_DATA_NULL" end),
"energopomoc": $is_ep,
"distribucia_kwh_bez_dph": ($dist_total_kontext * 1000000 | round / 1000000),
"marza_vykupu_kwh_bez_dph": $v_marza_kwh,
"fix_zse": {
"silova_elektrina_kwh_bez_dph": $zse_sil_bez,
"silova_elektrina_kwh_s_dph": ($zse_sil_bez * $obchod_koef * 1000000 | round / 1000000),
"hlavny_istic_amper": $i_amp,
"hlavny_istic_fazy": $i_faz,
"mesacny_pausal_bez_dph": ($p_bez * 100000 | round / 100000),
"mesacny_pausal_s_dph": (($p_dph * 100) | round / 100),
"spolu_koncova_cena_s_dph": (($zse_koncova_cena_kwh_s_dph + $hodinovy_fix_s_dph) * 1000000 | round / 1000000)
}
},
"priemer": {
"denny_priemer_spot_koncova_cena_s_dph": (if $priemer_spot_s_dph != null then ($priemer_spot_s_dph * 1000000 | round / 1000000) else null end),
"referencna_cena_zse_s_dph": (($zse_koncova_cena_kwh_s_dph + $hodinovy_fix_s_dph) * 1000000 | round / 1000000),
"celkova_denna_bilancia_výhodnosti_priemer": (if $priemerna_vyhodnost == null then null elif $priemerna_vyhodnost > 0 then "Spot" else "Fix" end),
"pocet_plusovych_hodin": ($plusove_pol | length),
"pocet_minusovych_hodin": ($minusove_pol | length),
"zoznam_plusovych_hodin": $plusove_pol,
"zoznam_minusovych_hodin": $minusove_pol,
"priemerna_hodinova_uspora_s_dph": (if $priemerna_vyhodnost != null then ($priemerna_vyhodnost * 1000000 | round / 1000000) else null end),
"najlacnejsi_usek": {
"cas": (if $mame_sietove_data then $min_cas else null end),
"koncova_cena_s_dph": (if $mame_sietove_data then $min_cena else null end)
},
"najdrahsi_usek": {
"cas": (if $mame_sietove_data then $max_cas else null end),
"koncova_cena_s_dph": (if $mame_sietove_data then $max_cena else null end)
}
},
"hodinovy_prehlad": $hodiny
}')
echo "$MOJ_VYSTUP_JSON"


# ==============================================================================
# 6. ZOBRAZENIE PRVÉHO VÝSTUPU
# ==============================================================================
echo "========================================================================"
echo " 1. PREPOČÍTANÝ JSON VÝSTUP (DÁTA PRE SMART HOME / GRAFY):"
echo "========================================================================"
echo "$MOJ_VYSTUP_JSON" > docs/energia.json
echo "Hotovo. Výstup bol úspešne zapísaný do súboru docs/energia.json."





# ==============================================================================
# 7. SPRACOVANIE A ODOSLANIE DO CLOUDFLARE AI
# ==============================================================================
# Definícia inštrukcií pre model Llama (System Prompt) s dôrazom na anomálie cien
SYSTEM_PROMPT="Tvojou úlohou je analyzovať priložené energetické dáta a vrátiť stručný sumár v spisovnom slovenskom jazyku.

ODPOVEDAJ VÝHRADNE v čistom formáte JSON. Je prísne zakázané používať akékoľvek textové komentáre, úvody, závery alebo Markdown ohraničenia typu \`\`\`json ... \`\`\`. Výstupom musí byť iba surový JSON objekt.

V analytickej časti venuj špeciálnu pozornosť situáciám, kedy sú ceny na burze záporné (menej ako 0), a vysvetli tento paradox (trhový prebytok). Všetky texty formuluj v budúcom čase (vzhľadom na to, že analyzuješ ceny na zajtrajší deň).

Výstup musí striktne dodržať túto štruktúru kľúčov:
{
  \"uvod\": \"Stručný úvod analýzy zajtrajšieho dňa. Ak sa v dátach vyskytujú záporné burzové ceny, označ to ako trhový paradox a prebytok v sieti.\",
  \"najlacnejsia\": \"Presné časové rozmedzie najlacnejšieho úseku. Ak je cena záporná alebo nulová, explicitne uveď, že silová zložka bude zadarmo a spotrebiteľ zaplatí iba distribúciu.\",
  \"najdrahsia\": \"Presné časové rozmedzie najdrahšieho úseku s vysvetlením, že ide o rannú/večernú špičku, kedy je spot vysoko nevýhodný.\",
  \"odporucanie\": \"Jasné a akčné odporúčanie pre Smart Home systémy (napr. kedy presne spustiť ohrev vody, nabíjanie batérií či spotrebičov a kedy spotrebu úplne zablokovať).\",
  \"spot\": \"Vyhodnotenie spotového priemeru. Uveď, za akých presných podmienok správania sa spotrebiteľovi zajtra oplatí dynamický spot pri teoretickom odbere 1 kW (napr. posun odberu do poobedňajších hodín).\",
  \"fix\": \"Vyhodnotenie fixného cenníka ZSE. Uveď, prečo a kedy bude fixný cenník zajtra pre spotrebiteľa bezpečnejšou voľbou (napr. pri kontinuálnom odbere bez možnosti regulácie v čase špičiek).\"
}"


# Bezpečné vytvorenie JSON Payloadu pre Cloudflare pomocou jq
PAYLOAD=$(jq -n \
  --arg sys "$SYSTEM_PROMPT" \
  --arg user "$MOJ_VYSTUP_JSON" \
  '{
    max_tokens: 1024,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: $sys },
      { role: "user", content: $user }
    ]
  }')

# Odoslanie POST dopytu na API Cloudflare
ODPOVED_AI=$(curl -s "https://api.cloudflare.com/client/v4/accounts/$(echo "${CLOUDFLARE_ACCOUNT_ID}")/ai/run/@cf/meta/llama-3.3-70b-instruct-fp8-fast" \
  -X POST \
  -H "X-Auth-Email: $(echo "${CLOUDFLARE_EMAIL}")" \
  -H "X-Auth-key: $(echo "${CLOUDFLARE_API_TOKEN}")" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# ==============================================================================
# 8. VÝSTUP DO TERMINÁLU
# ==============================================================================
echo "========================================================================"
echo " ANALÝZA SPOTU OD AI (Llama 3.2):"
echo "========================================================================"
echo "$ODPOVED_AI" | jq -r '.result.response // .response // .'  > docs/ai.json
echo "========================================================================"
