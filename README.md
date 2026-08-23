# RS Banking

Bank- en pinautomaatresource voor ESX Legacy, gekoppeld aan RS Economie.

## Functies

- Banklocaties via ox_target
- Ondersteuning voor alle standaard GTA-pinautomaten
- Veilige viercijferige pincode met salted SHA-256-opslag
- Pogingenlimiet en tijdelijke pasblokkering
- Contant opnemen en storten
- Configureerbare transactiekosten
- Optionele bankpascontrole via ox_inventory
- Transacties zichtbaar in RS Economie
- Logging via rs_discordlogs met webhook-fallback

Importeer `sql/rs-banking.sql` en start de resource na `rs-economie`.

```cfg
ensure rs-economie
ensure rs-banking
```

Copyright © 2026 Rico Scripts. Herdistributie of doorverkoop is niet toegestaan.
