const FS = require('fs')

function ReplaceContractPathToOxName(contractContent) {
    // replace "../....../../xxx.cdc" => 0xxx
    return contractContent.replace(/from \"[.\/]+.*\/(.*).cdc\"/g, 'from 0x$1')
}

function LoadCode(path) {
    // TODO file system loading is just for testing, and the code loading should be static (e.g. string storage).
    return FS.readFileSync(path, 'utf8')
}

// Convert "FlowToken" -> "flowToken"
function ConvertTokenNameToLowerName(TokenName) {
    if(TokenName == "FUSD") return "fusd"
    return TokenName.replace(TokenName[0], TokenName[0].toLowerCase())
}

module.exports = {
    ReplaceContractPathToOxName,
    LoadCode,
    ConvertTokenNameToLowerName
}