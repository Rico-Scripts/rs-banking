Config = {}

Config.RequireBankCard = false
Config.BankCardItem = 'bank_card'
Config.WithdrawFee = 1.0
Config.MaxATMAmount = 100000
Config.SessionSeconds = 120
Config.MaxPinAttempts = 3
Config.BlockMinutes = 15
Config.InteractionDistance = 2.0

Config.ATMModels = {
    `prop_atm_01`, `prop_atm_02`, `prop_atm_03`, `prop_fleeca_atm`
}

Config.BankLocations = {
    vec3(149.46, -1040.17, 29.37),
    vec3(-1212.98, -330.84, 37.78),
    vec3(-2962.58, 482.63, 15.70),
    vec3(314.19, -278.62, 54.17),
    vec3(-351.53, -49.53, 49.04),
    vec3(1175.06, 2706.64, 38.09),
    vec3(-112.86, 6469.94, 31.63)
}

Config.Webhook = ''
Config.LogColors = { info = 3447003, success = 5763719, danger = 15548997 }
