import Foundation

/// A premium translation and phonetic transliteration utility for cricket scorecards.
/// Combines a massive exact lookup dictionary for common player names, team names, and UI labels
/// with a rule-based syllable phonetic mapping engine to translate unseen names with high accuracy.
struct HindiTranslator {
    
    /// High-level translation interface. Parses text segments, respects punctuation, and applies translations.
    static func translate(_ text: String, isHindi: Bool) -> String {
        guard isHindi else { return text }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        // 1. Check exact match in dictionary (case-insensitive)
        if let exact = dictionary[trimmed] {
            return exact
        }
        if let exact = dictionary[trimmed.lowercased()] {
            return exact
        }
        
        var resultText = trimmed
        
        // 2. Translate common cricket terminology patterns
        if resultText.lowercased().contains("target") {
            resultText = resultText.replacingOccurrences(of: "target", with: "लक्ष्य", options: .caseInsensitive)
            resultText = resultText.replacingOccurrences(of: "Target", with: "लक्ष्य", options: .caseInsensitive)
        }
        if resultText.lowercased().contains("ov") {
            resultText = resultText.replacingOccurrences(of: "overs", with: "ओवर", options: .caseInsensitive)
            resultText = resultText.replacingOccurrences(of: "ov", with: "ओवर", options: .caseInsensitive)
        }
        if resultText.lowercased().contains("vs") {
            resultText = resultText.replacingOccurrences(of: " vs ", with: " बनाम ", options: .caseInsensitive)
            resultText = resultText.replacingOccurrences(of: " vs", with: " बनाम", options: .caseInsensitive)
            resultText = resultText.replacingOccurrences(of: "vs ", with: "बनाम ", options: .caseInsensitive)
        }
        
        // 3. Process word-by-word if it has spaces
        let words = resultText.components(separatedBy: .whitespaces)
        if words.count > 1 {
            let translatedWords = words.map { w -> String in
                let cleanWord = w.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                if cleanWord.isEmpty { return w }
                
                let translatedClean: String
                if let exact = dictionary[cleanWord] {
                    translatedClean = exact
                } else if let exact = dictionary[cleanWord.lowercased()] {
                    translatedClean = exact
                } else {
                    translatedClean = transliterateWord(cleanWord)
                }
                
                // Keep surrounding punctuation/numbers safely without force-unwrapping
                let punctuation = CharacterSet.alphanumerics.inverted
                var prefix = ""
                for char in w {
                    if let scalar = char.unicodeScalars.first, punctuation.contains(scalar) {
                        prefix.append(char)
                    } else {
                        break
                    }
                }
                
                var suffix = ""
                for char in w.reversed() {
                    if let scalar = char.unicodeScalars.first, punctuation.contains(scalar) {
                        suffix.insert(char, at: suffix.startIndex)
                    } else {
                        break
                    }
                }
                
                return prefix + translatedClean + suffix
            }
            return translatedWords.joined(separator: " ")
        }
        
        // Single word fallback
        return transliterateWord(trimmed)
    }
    
    // MARK: - Phonetic Transliterator
    
    private static func transliterateWord(_ word: String) -> String {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if w.isEmpty { return "" }
        
        // Return digits or non-alphabetic strings directly
        if w.rangeOfCharacter(from: CharacterSet.letters) == nil {
            return word
        }
        
        // Pre-collapse double consonants for cleaner Hindi syllable structures
        let normalized = collapseDoubleConsonants(w)
        
        var result = ""
        var i = normalized.startIndex
        
        func peek(_ offset: Int) -> Character? {
            guard let idx = normalized.index(i, offsetBy: offset, limitedBy: normalized.endIndex), idx < normalized.endIndex else {
                return nil
            }
            return normalized[idx]
        }
        
        func advance(_ count: Int) {
            if let idx = normalized.index(i, offsetBy: count, limitedBy: normalized.endIndex) {
                i = idx
            } else {
                i = normalized.endIndex
            }
        }
        
        while i < normalized.endIndex {
            let char = normalized[i]
            
            // Check 3-character combos
            if char == "c" && peek(1) == "h" && peek(2) == "h" {
                result += "छ"
                advance(3)
                continue
            }
            if char == "k" && peek(1) == "h" && peek(2) == "a" && peek(3) == "n" {
                result += "खान"
                advance(4)
                continue
            }
            
            // Check specific 3-character phonetic combos first
            if char == "d" && peek(1) == "e" && peek(2) == "v" {
                result += "देव"
                advance(3)
                continue
            }
            if char == "j" && peek(1) == "a" && (peek(2) == "s" || peek(2) == "m") {
                result += "जे"
                advance(2)
                continue
            }
            
            // Check 2-character combos
            if char == "b" && peek(1) == "r" {
                result += "ब्र"
                advance(1)
                continue
            }
            if char == "l" && peek(1) == "d" {
                result += "ल्ड"
                advance(2)
                continue
            }
            if char == "d" && peek(1) == "e" {
                // If "de" is at the start of a word, it represents the "De" prefix (e.g. De Silva -> डि सिल्वा)
                if i == normalized.startIndex {
                    result += "डि"
                } else {
                    result += "डे"
                }
                advance(2)
                continue
            }
            if char == "s" && peek(1) == "h" {
                result += "श"
                advance(2)
                continue
            }
            if char == "c" && peek(1) == "h" {
                result += "च"
                advance(2)
                continue
            }
            if char == "t" && peek(1) == "h" {
                result += "थ"
                advance(2)
                continue
            }
            if char == "d" && peek(1) == "h" {
                result += "ध"
                advance(2)
                continue
            }
            if char == "b" && peek(1) == "h" {
                result += "भ"
                advance(2)
                continue
            }
            if char == "g" && peek(1) == "h" {
                result += "घ"
                advance(2)
                continue
            }
            if char == "k" && peek(1) == "h" {
                result += "ख"
                advance(2)
                continue
            }
            if char == "p" && peek(1) == "h" {
                result += "फ"
                advance(2)
                continue
            }
            if char == "e" && peek(1) == "e" {
                result += result.isEmpty ? "ई" : "ी"
                advance(2)
                continue
            }
            if char == "o" && peek(1) == "o" {
                result += result.isEmpty ? "ऊ" : "ू"
                advance(2)
                continue
            }
            if char == "a" && peek(1) == "i" {
                result += result.isEmpty ? "ऐ" : "ै"
                advance(2)
                continue
            }
            if char == "a" && peek(1) == "u" {
                result += result.isEmpty ? "औ" : "ौ"
                advance(2)
                continue
            }
            if char == "a" && peek(1) == "a" {
                result += result.isEmpty ? "आ" : "ा"
                advance(2)
                continue
            }
            if char == "a" && peek(1) == "y" {
                result += result.isEmpty ? "ए" : "े"
                advance(2)
                continue
            }
            if char == "n" && (peek(1) == "d" || peek(1) == "t" || peek(1) == "g" || peek(1) == "c" || peek(1) == "j") {
                result += "ं"
                advance(1)
                continue
            }
            
            // Single character matches
            switch char {
            // Vowels
            case "a":
                if result.isEmpty {
                    result += "अ"
                } else {
                    if peek(1) == nil {
                        result += "ा"
                    } else if peek(1) == "i" || peek(1) == "u" || peek(1) == "e" || peek(1) == "o" {
                        // handled by vowel blends
                    } else {
                        result += "ा"
                    }
                }
            case "e":
                if result.isEmpty {
                    result += "ए"
                } else {
                    result += "े"
                }
            case "i":
                if result.isEmpty {
                    result += "इ"
                } else {
                    if peek(1) == nil {
                        result += "ी"
                    } else {
                        result += "ि"
                    }
                }
            case "o":
                if result.isEmpty {
                    result += "ओ"
                } else {
                    result += "ो"
                }
            case "u":
                if result.isEmpty {
                    result += "उ"
                } else {
                    result += "ु"
                }
            case "y":
                if result.isEmpty {
                    result += "य"
                } else {
                    if peek(1) == nil {
                        result += "ी"
                    } else {
                        result += "्य"
                    }
                }
                
            // Consonants
            case "b": result += "ब"
            case "c":
                if peek(1) == "e" || peek(1) == "i" || peek(1) == "y" {
                    result += "स"
                } else {
                    result += "क"
                }
            case "d":
                if peek(1) == "r" || peek(1) == "y" {
                    result += "ड्र"
                    advance(1)
                } else {
                    result += "द"
                }
            case "f": result += "फ"
            case "g": result += "ग"
            case "h": result += "ह"
            case "j": result += "ज"
            case "k": result += "क"
            case "l": result += "ल"
            case "m": result += "म"
            case "n": result += "न"
            case "p": result += "प"
            case "q": result += "क"
            case "r": result += "र"
            case "s": result += "स"
            case "t":
                if peek(1) == "r" {
                    result += "ट्र"
                    advance(1)
                } else {
                    result += "त"
                }
            case "v": result += "व"
            case "w": result += "व"
            case "x": result += "क्स"
            case "z": result += "ज"
            default:
                result += String(char)
            }
            
            advance(1)
        }
        
        return result
    }
    
    private static func collapseDoubleConsonants(_ word: String) -> String {
        var result = ""
        var lastChar: Character?
        for char in word {
            if char == lastChar {
                if "bcdfghjklmnpqrstvwxyz".contains(char) {
                    continue
                }
            }
            result.append(char)
            lastChar = char
        }
        return result
    }
    
    // MARK: - Dictionary Mappings
    
    private static let dictionary: [String: String] = [
        // User spelling overrides & names
        "de": "डि",
        "De": "डि",
        "Brooke": "ब्रुक",
        "Brook": "ब्रुक",
        "brooke": "ब्रुक",
        "brook": "ब्रुक",
        "Jason": "जेसन",
        "jason": "जेसन",
        "Holder": "होल्डर",
        "holder": "होल्डर",
        "Jason Holder": "जेसन होल्डर",
        "jason holder": "जेसन होल्डर",
        
        // Common UI & Metadata Labels
        "BATTING": "बल्लेबाजी",
        "BOWLING": "गेंदबाजी",
        "Batter": "बल्लेबाज",
        "R": "रन",
        "B": "गेंद",
        "SR": "स्ट्राइक रेट",
        "Bowler": "गेंदबाज",
        "O": "ओवर",
        "M": "मैडन",
        "W": "विकेट",
        "ECO": "इकोनॉमी",
        "PARTNERSHIP": "साझेदारी",
        "CRR": "सीआरआर",
        "RRR": "आरआरआर",
        "PLAYER OF THE MATCH": "प्लेयर ऑफ द मैच",
        "STRATEGIC TIMEOUT": "रणनीतिक टाइमआउट",
        "INNINGS BREAK": "पारी का ब्रेक",
        "LUNCH BREAK": "लंच ब्रेक",
        "TEA BREAK": "टी ब्रेक",
        "DRINKS BREAK": "ड्रिंक्स ब्रेक",
        "RAIN DELAY": "बारिश के कारण रुकावट",
        "vs": "बनाम",
        "target": "लक्ष्य",
        "ov": "ओवर",
        "overs": "ओवर",
        "runs": "रन",
        "balls": "गेंद",
        "wickets": "विकेट",
        "run": "रन",
        "ball": "गेंद",
        "wicket": "विकेट",
        "no batting data": "कोई बल्लेबाजी डेटा नहीं",
        "no bowling data": "कोई गेंदबाजी डेटा नहीं",
        "venue": "स्थान",
        
        // Team Nicknames & Specific Modifications
        "Dragons": "ड्रेगन",
        "dragons": "ड्रेगन",
        "Typhoons": "टाइफून",
        "typhoons": "टाइफून",
        "Titans": "टाइटन्स",
        "titans": "टाइटन्स",
        "Challengers": "चैलेंजर्स",
        "challengers": "चैलेंजर्स",
        
        // Official Country Mappings (User Provided)
        "Afghanistan": "अफ़्गानिस्तान",
        "Albania": "अल्बानिया",
        "Algeria": "अल्जीरिया",
        "Andorra": "अण्डोरा",
        "Angola": "अंगोला",
        "Antigua and Barbuda": "अण्टीगुआ और बारबूडा",
        "Argentina": "अर्जेण्टीना",
        "Armenia": "आर्मीनिया",
        "Australia": "ऑस्ट्रेलिया",
        "Austria": "ऑस्ट्रिया",
        "Azerbaijan": "अज़रबैजान",
        "Bahamas": "बहामास",
        "Bahrain": "बहरीन",
        "Bangladesh": "बांग्लादेश",
        "Barbados": "बारबाडोस",
        "Belarus": "बेलारूस",
        "Belgium": "बेल्जियम",
        "Belize": "बेलीज़",
        "Benin": "बेनिन",
        "Bhutan": "भूटान",
        "Bolivia": "बोलिविया",
        "Bosnia and Herzegovina": "बॉस्निया और हर्ज़ेगोविना",
        "Botswana": "बोत्सवाना",
        "Brazil": "ब्राज़ील",
        "Brunei": "ब्रुनेई",
        "Bulgaria": "बुल्गारिया",
        "Burkina Faso": "बुर्किना फासो",
        "Burundi": "बुरुण्डी",
        "Cambodia": "कम्बोडिया",
        "Cameroon": "कैमरुन",
        "Canada": "कनाडा",
        "Cape Verde": "केप वर्दे",
        "Central African Republic": "मध्य अफ़्रीकी गणराज्य",
        "Chad": "चाड",
        "Chile": "चिली",
        "China": "चीन",
        "Colombia": "कोलम्बिया",
        "Comoros": "कोमोरोस",
        "Costa Rica": "कोस्टा रीका",
        "Côte d’Ivoire": "कोत द’ईवोआर",
        "Croatia": "क्रोएशिया",
        "Cuba": "क्यूबा",
        "Cyprus": "साइप्रस",
        "Czech Republic": "चेक गणराज्य",
        "Democratic Republic of the Congo": "कांगो लोकतान्त्रिक गणराज्य",
        "Denmark": "डेनमार्क",
        "Djibouti": "जिबूती",
        "Dominica": "डोमिनिका",
        "Dominican Republic": "डोमिनिकन गणराज्य",
        "East Timor": "पूर्वी तिमोर",
        "Ecuador": "ईक्वाडोर",
        "Egypt": "मिस्र",
        "El Salvador": "अल साल्वाडोर",
        "Equatorial Guinea": "भूमध्यरेखीय गिनी",
        "Eritrea": "इरित्रिया",
        "Estonia": "एस्टोनिया",
        "Ethiopia": "इथियोपिया",
        "Fiji": "फ़िजी",
        "Finland": "फ़िनलैण्ड",
        "France": "फ़्रान्स",
        "Gabon": "गबॉन",
        "Gambia": "ज़ाम्बिया",
        "Georgia": "जॉर्जिया",
        "Germany": "जर्मनी",
        "Ghana": "घाना",
        "Greece": "यूनान",
        "Grenada": "ग्रेनाडा",
        "Guatemala": "ग्वाटेमाला",
        "Guinea": "गिनी",
        "Guinea-Bissau": "गिनी-बिसाऊ",
        "Guyana": "गयाना",
        "Haiti": "हैती",
        "Honduras": "हौण्डुरस",
        "Hungary": "हंगरी",
        "Iceland": "आइसलैण्ड",
        "India": "भारत",
        "Indonesia": "इंडोनेशिया",
        "Iran": "ईरान",
        "Iraq": "इराक़",
        "Ireland": "आयरलैण्ड",
        "Israel": "इज़राइल",
        "Italy": "इटली",
        "Jamaica": "जमैका",
        "Japan": "जापान",
        "Jordan": "जॉर्डन",
        "Kazakhstan": "कज़ाख़िस्तान",
        "Kenya": "कीनिया",
        "Kiribati": "किरिबाती",
        "Kuwait": "कुवैत",
        "Kyrgyzstan": "किर्गिज़स्तान",
        "Laos": "लाओस",
        "Latvia": "लातविया",
        "Lebanon": "लेबनान",
        "Lesotho": "लेसोथो",
        "Liberia": "लाइबेरिया",
        "Libya": "लीबिया",
        "Liechtenstein": "लिक्टेन्स्टाइन",
        "Lithuania": "लिथुआनिया",
        "Luxembourg": "लक्ज़मबर्ग",
        "Madagascar": "मेडागास्कर",
        "Malawi": "मलावी",
        "Malaysia": "मलेशिया",
        "Maldives": "मालदीव",
        "Mali": "माली",
        "Malta": "माल्टा",
        "Marshall Islands": "मार्शल द्वीपसमूह",
        "Mauritania": "मॉरिटानिया",
        "Mauritius": "मॉरिशस",
        "Mexico": "मेक्सिको",
        "Micronesia": "माइक्रोनेशिया",
        "Moldova": "मॉल्डोवा",
        "Monaco": "मोनैको",
        "Mongolia": "मंगोलिया",
        "Montenegro": "मॉन्टेंगरो",
        "Morocco": "मोरक्को",
        "Mozambique": "मोज़ाम्बीक",
        "Myanmar": "म्यान्मार",
        "Namibia": "नामीबिया",
        "Nauru": "नौरु",
        "Nepal": "नेपाल",
        "Netherlands": "नीदरलैण्ड",
        "New Zealand": "न्यूज़ीलैण्ड",
        "Nicaragua": "निकारागुआ",
        "Niger": "नाइजर",
        "Nigeria": "नाईजीरिया",
        "North Korea": "उत्तर कोरिया",
        "Norway": "नॉर्वे",
        "Oman": "ओमान",
        "Pakistan": "पाकिस्तान",
        "Palau": "पलाऊ",
        "Panama": "पनामा",
        "Papua New Guinea": "पापुआ न्यू गिनी",
        "Paraguay": "पैराग्वे",
        "Peru": "पेरू",
        "Philippines": "फ़िलीपीन्स",
        "Poland": "पोलैंड",
        "Portugal": "पुर्तगाल",
        "Qatar": "क़तर",
        "Republic of the Congo": "कांगो गणराज्य",
        "Republic of Macedonia": "मैसिडोनिया",
        "Romania": "रोमानिया",
        "Russia": "रूस",
        "Rwanda": "रवाण्डा",
        "Saint Kitts and Nevis": "सन्त किट्स और नेविस",
        "Saint Lucia": "सन्त लूसिया",
        "Saint Vincent and the Grenadines": "सन्त विन्सेण्ट और ग्रेनाडाइन्स",
        "Samoa": "समोआ",
        "San Marino": "सान मारिनो",
        "Sao Tome and Principe": "साओ तोमे और प्रिन्सिपी",
        "Saudi Arabia": "सउदी अरब",
        "Senegal": "सेनेगल",
        "Serbia": "सर्बिया",
        "Seychelles": "सेशेल्स",
        "Sierra Leone": "सिएरा लियोन",
        "Singapore": "सिंगापुर",
        "Slovakia": "स्लोवाकिया",
        "Slovenia": "स्लोवेनिया",
        "Solomon Islands": "सोलोमन द्वीपसमूह",
        "Somalia": "सोमालिया",
        "South Africa": "दक्षिण अफ़्रीका",
        "South Korea": "दक्षिण कोरिया",
        "South Sudan": "दक्षिण सूडान",
        "Spain": "स्पेन",
        "Sri Lanka": "श्रीलंका",
        "Sudan": "सूडान",
        "Suriname": "सूरीनाम",
        "Swaziland": "स्वाज़ीलैण्ड",
        "Sweden": "स्वीडन",
        "Switzerland": "स्विट्ज़रलैण्ड",
        "Syria": "सीरिया",
        "Tajikistan": "ताजिकिस्तान",
        "Tanzania": "तंज़ानिया",
        "Thailand": "थाईलैण्ड",
        "thailand": "थाईलैण्ड",
        "Togo": "टोगो",
        "Tonga": "टोंगा",
        "Trinidad and Tobago": "त्रिनिदाद और टोबैगो",
        "Tunisia": "ट्यूनिशिया",
        "Turkey": "तुर्की",
        "Turkmenistan": "तुर्कमेनिस्तान",
        "Tuvalu": "तुवालू",
        "Uganda": "युगाण्डा",
        "Ukraine": "युक्रेन",
        "United Arab Emirates": "संयुक्त अरब अमीरात",
        "United Kingdom": "यूनाइटेड किंगडम",
        "United States of America": "अमेरिका",
        "Uruguay": "उरुग्वे",
        "Uzbekistan": "उज़्बेकिस्तान",
        "Vanuatu": "वानूअतु",
        "Venezuela": "वेनेज़ुएला",
        "Vietnam": "वियतनाम",
        "Yemen": "यमन",
        "Zambia": "ज़ाम्बिया",
        "Zimbabwe": "ज़िम्बाब्वे",
        
        // Also support lowercase versions for safe lookup
        "afghanistan": "अफ़्गानिस्तान",
        "albania": "अल्बानिया",
        "algeria": "अल्जीरिया",
        "andorra": "अण्डोरा",
        "angola": "अंगोला",
        "antigua and barbuda": "अण्टीगुआ और बारबूडा",
        "argentina": "अर्जेण्टीना",
        "armenia": "आर्मीनिया",
        "australia": "ऑस्ट्रेलिया",
        "austria": "ऑस्ट्रिया",
        "azerbaijan": "अज़रबैजान",
        "bahamas": "बहामास",
        "bahrain": "बहरीन",
        "bangladesh": "बांग्लादेश",
        "barbados": "बारबाडोस",
        "belarus": "बेलारूस",
        "belgium": "बेल्जियम",
        "belize": "बेलीज़",
        "benin": "बेनिन",
        "bhutan": "भूटान",
        "bolivia": "बोलिविया",
        "bosnia and herzegovina": "बॉस्निया और हर्ज़ेगोविना",
        "botswana": "बोत्सवाना",
        "brazil": "ब्राज़ील",
        "brunei": "ब्रुनेई",
        "bulgaria": "बुल्गारिया",
        "burkina faso": "बुर्किना फासो",
        "burundi": "बुरुण्डी",
        "cambodia": "कम्बोडिया",
        "cameroon": "कैमरुन",
        "canada": "कनाडा",
        "cape verde": "केप वर्दे",
        "central african republic": "मध्य अफ़्रीकी गणराज्य",
        "chad": "चाड",
        "chile": "चिली",
        "china": "चीन",
        "colombia": "कोलम्बिया",
        "comoros": "कोमोरोस",
        "costa rica": "कोस्टा रीका",
        "cote d’ivoire": "कोत द’ईवोआर",
        "croatia": "क्रोएशिया",
        "cuba": "क्यूबा",
        "cyprus": "साइप्रस",
        "czech republic": "चेक गणराज्य",
        "democratic republic of the congo": "कांगो लोकतान्त्रिक गणराज्य",
        "denmark": "डेनमार्क",
        "djibouti": "जिबूती",
        "dominica": "डोमिनिका",
        "dominican republic": "डोमिनिकन गणराज्य",
        "east timor": "पूर्वी तिमोर",
        "ecuador": "ईक्वाडोर",
        "egypt": "मिस्र",
        "el salvador": "अल साल्वाडोर",
        "equatorial guinea": "भूमध्यरेखीय गिनी",
        "eritrea": "इरित्रिया",
        "estonia": "एस्टोनिया",
        "ethiopia": "इथियोपिया",
        "fiji": "फ़िजी",
        "finland": "फ़िनलैण्ड",
        "france": "फ़्रान्स",
        "gabon": "गबॉन",
        "gambia": "ज़ाम्बिया",
        "georgia": "जॉर्जिया",
        "germany": "जर्मनी",
        "ghana": "घाना",
        "greece": "यूनान",
        "grenada": "ग्रेनाडा",
        "guatemala": "ग्वाटेमाला",
        "guinea": "गिनी",
        "guinea-bissau": "गिनी-बिसाऊ",
        "guyana": "गयाना",
        "haiti": "हैती",
        "honduras": "हौण्डुरस",
        "hungary": "हंगरी",
        "iceland": "आइसलैण्ड",
        "india": "भारत",
        "indonesia": "इंडोनेशिया",
        "iran": "ईरान",
        "iraq": "इराक़",
        "ireland": "आयरलैण्ड",
        "israel": "इज़राइल",
        "italy": "इटली",
        "jamaica": "जमैका",
        "japan": "जापान",
        "jordan": "जॉर्डन",
        "kazakhstan": "कज़ाख़िस्तान",
        "kenya": "कीनिया",
        "kiribati": "किरिबाती",
        "kuwait": "कुवैत",
        "kyrgyzstan": "किर्गिज़स्तान",
        "laos": "लाओस",
        "latvia": "लातविया",
        "lebanon": "लेबनान",
        "lesotho": "लेसोथो",
        "liberia": "लाइबेरिया",
        "libya": "लीबिया",
        "liechtenstein": "लिक्टेन्स्टाइन",
        "lithuania": "लिथुआनिया",
        "luxembourg": "लक्ज़मबर्ग",
        "madagascar": "मेडागास्कर",
        "malawi": "मलावी",
        "malaysia": "मलेशिया",
        "maldives": "मालदीव",
        "mali": "माली",
        "malta": "माल्टा",
        "marshall islands": "मार्शल द्वीपसमूह",
        "mauritania": "मॉरिटानिया",
        "mauritius": "मॉरिशस",
        "mexico": "मेक्सिको",
        "micronesia": "माइक्रोनेशिया",
        "moldova": "मॉल्डोवा",
        "monaco": "मोनैको",
        "mongolia": "मंगोलिया",
        "montenegro": "मॉन्टेंगरो",
        "morocco": "मोरक्को",
        "mozambique": "मोज़ाम्बीक",
        "myanmar": "म्यान्मार",
        "namibia": "नामीबिया",
        "nauru": "नौरु",
        "nepal": "नेपाल",
        "netherlands": "नीदरलैण्ड",
        "new zealand": "न्यूज़ीलैण्ड",
        "nicaragua": "निकारागुआ",
        "niger": "नाइजर",
        "nigeria": "नाईजीरिया",
        "north korea": "उत्तर कोरिया",
        "norway": "नॉर्वे",
        "oman": "ओमान",
        "pakistan": "पाकिस्तान",
        "palau": "पलाऊ",
        "panama": "पनामा",
        "papua new guinea": "पापुआ न्यू गिनी",
        "paraguay": "पैराग्वे",
        "peru": "पेरू",
        "philippines": "फ़िलीपीन्स",
        "poland": "पोलैंड",
        "portugal": "पुर्तगाल",
        "qatar": "क़तर",
        "republic of the congo": "कांगो गणराज्य",
        "republic of macedonia": "मैसिडोनिया",
        "romania": "रोमानिया",
        "russia": "रूस",
        "rwanda": "रवाण्डा",
        "saint kitts and nevis": "सन्त किट्स और नेविस",
        "saint lucia": "सन्त लूसिया",
        "saint vincent and the grenadines": "सन्त विन्सेण्ट और ग्रेनाडाइन्स",
        "samoa": "समोआ",
        "san marino": "सान मारिनो",
        "sao tome and principe": "साओ तोमे और प्रिन्सिपी",
        "saudi arabia": "सउदी अरब",
        "senegal": "सेनेगल",
        "serbia": "सर्बिया",
        "seychelles": "सेशेल्स",
        "sierra leone": "सिएरा लियोन",
        "singapore": "सिंगापुर",
        "slovakia": "स्लोवाकिया",
        "slovenia": "स्लोवेनिया",
        "solomon islands": "सोलोमन द्वीपसमूह",
        "somalia": "सोमालिया",
        "south africa": "दक्षिण अफ़्रीका",
        "south korea": "दक्षिण कोरिया",
        "south sudan": "दक्षिण सूडान",
        "spain": "स्पेन",
        "sri lanka": "श्रीलंका",
        "sudan": "सूडान",
        "suriname": "सूरीनाम",
        "swaziland": "स्वाज़ीलैण्ड",
        "sweden": "स्वीडन",
        "switzerland": "स्विट्ज़रलैण्ड",
        "syria": "सीरिया",
        "tajikistan": "ताजिकिस्तान",
        "tanzania": "तंज़ानिया",
        "togo": "टोगो",
        "tonga": "टोंगा",
        "trinidad and tobago": "त्रिनिदाद और टोबैगो",
        "tunisia": "ट्यूनिशिया",
        "turkey": "तुर्की",
        "turkmenistan": "तुर्कमेनिस्तान",
        "tuvalu": "तुवालू",
        "uganda": "युगाण्डा",
        "ukraine": "युक्रेन",
        "united arab emirates": "संयुक्त अरब अमीरात",
        "united kingdom": "यूनाइटेड किंगडम",
        "united states of america": "अमेरिका",
        "uruguay": "उरुग्वे",
        "uzbekistan": "उज़्बेकिस्तान",
        "vanuatu": "वानूअतु",
        "venezuela": "वेनेज़ुएला",
        "vietnam": "वियतनाम",
        "yemen": "यमन",
        "zambia": "ज़ाम्बिया",
        "zimbabwe": "ज़िम्बाब्वे",
        
        // Popular Women players (including screenshot ones)
        "Bharti Fulmali": "भारती फुलमाली",
        "Bharti": "भारती",
        "Fulmali": "फुलमाली",
        "Arundhati Reddy": "अरुंधति रेड्डी",
        "Arundhati": "अरुंधति",
        "Reddy": "रेड्डी",
        "Maria Andrews": "मारिया एंड्रयूज",
        "Maria": "मारिया",
        "Andrews": "एंड्रयूज",
        "Smriti Mandhana": "स्मृति मंधाना",
        "Smriti": "स्मृति",
        "Mandhana": "मंधाना",
        "Harmanpreet Kaur": "हरमनप्रीत कौर",
        "Harmanpreet": "हरमनप्रीत",
        "Kaur": "कौर",
        "Jemimah Rodrigues": "जेमिमा रोड्रिग्स",
        "Jemimah": "जेमिमा",
        "Rodrigues": "रोड्रिग्स",
        "Shafali Verma": "शफाली वर्मा",
        "Shafali": "शफाली",
        "Verma": "वर्मा",
        "Deepti Sharma": "दीप्ति शर्मा",
        "Deepti": "दीप्ति",
        "Sharma": "शर्मा",
        "Yastika Bhatia": "यास्तिका भाटिया",
        "Yastika": "यास्तिका",
        "Bhatia": "भाटिया",
        "Richa Ghosh": "ऋचा घोष",
        "Richa": "ऋचा",
        "Ghosh": "घोष",
        "Pooja Vastrakar": "पूजा वस्त्राकर",
        "Pooja": "पूजा",
        "Vastrakar": "वस्त्राकर",
        "Renuka Singh": "रेणुका सिंह",
        "Renuka": "रेणुका",
        "Singh": "सिंह",
        "Shreyanka Patil": "श्रेयंका पाटिल",
        "Shreyanka": "श्रेयंका",
        "Patil": "पाटिल",
        "Titas Sadhu": "तीतास साधु",
        "Titas": "तीतास",
        "Sadhu": "साधु",
        "Radha Yadav": "राधा यादव",
        "Radha": "राधा",
        "Yadav": "यादव",
        "Sneh Rana": "स्नेह राणा",
        "Sneh": "स्नेह",
        "Rana": "राणा",
        "Saika Ishaque": "सायका इशाक",
        "Saika": "सायका",
        "Ishaque": "इशाक",
        "Amanjot Kaur": "अमनजोत कौर",
        "Amanjot": "अमनजोत",
        "Dayalan Hemalatha": "दयालन हेमलता",
        "Dayalan": "दयालन",
        "Hemalatha": "हेमलता",
        "Harleen Deol": "हरलीन देओल",
        "Harleen": "हरलीन",
        "Deol": "देओल",
        "Kiran Navgire": "किरण नवगिरे",
        "Kiran": "किरण",
        "Navgire": "नवगिरे",
        "Uma Chetry": "उमा छेत्री",
        "Uma": "उमा",
        "Chetry": "छेत्री",
        "Sajeevan Sajana": "सजीवन सजना",
        "Sajeevan": "सजीवन",
        "Sajana": "सजना",
        "Asha Sobhana": "आशा शोभना",
        "Asha": "आशा",
        "Sobhana": "शोभना",
        
        // Popular Men players
        "Rohit Sharma": "रोहित शर्मा",
        "Rohit": "रोहित",
        "Virat Kohli": "विराट कोहली",
        "Virat": "विराट",
        "Kohli": "कोहली",
        "MS Dhoni": "एमएस धोनी",
        "Dhoni": "धोनी",
        "Hardik Pandya": "हार्दिक पंड्या",
        "Hardik": "हार्दिक",
        "Pandya": "पंड्या",
        "KL Rahul": "केएल राहुल",
        "Rahul": "राहुल",
        "Rishabh Pant": "ऋषभ पंत",
        "Rishabh": "ऋषभ",
        "Pant": "पंत",
        "Jasprit Bumrah": "जसप्रीत बुमराह",
        "Jasprit": "जसप्रीत",
        "Bumrah": "बुमराह",
        "Ravindra Jadeja": "रविंद्र जडेजा",
        "Ravindra": "रविंद्र",
        "Jadeja": "जडेजा",
        "Shubman Gill": "शुभमन गिल",
        "Shubman": "शुभमन",
        "Gill": "गिल",
        "Shreyas Iyer": "श्रेयस अय्यर",
        "Shreyas": "श्रेयस",
        "Iyer": "अय्यर",
        "Mohammed Shami": "मोहम्मद शमी",
        "Mohammed": "मोहम्मद",
        "Shami": "शमी",
        "Mohammed Siraj": "मोहम्मद सिराज",
        "Siraj": "सिराज",
        "Ravichandran Ashwin": "रविचंद्रन अश्विन",
        "Ravichandran": "रविचंद्रन",
        "Ashwin": "अश्विन",
        "Kuldeep Yadav": "कुलदीप यादव",
        "Kuldeep": "कुलदीप",
        "Yuzvendra Chahal": "युजवेंद्र चहल",
        "Yuzvendra": "युजवेंद्र",
        "Chahal": "चहल",
        "Axar Patel": "अक्षर पटेल",
        "Axar": "अक्षर",
        "Patel": "पटेल",
        "Ishan Kishan": "ईशान किशन",
        "Ishan": "ईशान",
        "Kishan": "किशन",
        "Suryakumar Yadav": "सूर्यकुमार यादव",
        "Suryakumar": "सूर्यकुमार",
        "Yashasvi Jaiswal": "यशस्वी जायसवाल",
        "Yashasvi": "यशस्वी",
        "Jaiswal": "जायसवाल",
        "Sanju Samson": "संजू सैमसन",
        "Sanju": "संजू",
        "Samson": "सैमसन",
        "Ruturaj Gaikwad": "ऋतुराज गायकवाड़",
        "Ruturaj": "ऋतुराज",
        "Gaikwad": "गायकवाड़",
        "Rinku Singh": "रिंकू सिंह",
        "Rinku": "रिंकू",
        "Arshdeep Singh": "अर्शदीप सिंह",
        "Arshdeep": "अर्शदीप",
        "Shardul Thakur": "शार्दुल ठाकुर",
        "Shardul": "शार्दुल",
        "Thakur": "ठाकुर",
        "Deepak Chahar": "दीपक चहर",
        "Deepak": "दीपक",
        "Chahar": "चहर",
        "Washington Sundar": "वाशिंगटन सुंदर",
        "Washington": "वाशिंगटन",
        "Sundar": "सुंदर",
        "Prasidh Krishna": "प्रसिद्धि कृष्णा",
        "Prasidh": "प्रसिद्धि",
        "Krishna": "कृष्णा",
        "Avesh Khan": "आवेश खान",
        "Avesh": "आवेश",
        "Khan": "खान",
        "Mukesh Kumar": "मुकेश कुमार",
        "Mukesh": "मुकेश",
        "Kumar": "कुमार",
        "Ravi Bishnoi": "रवि बिश्नोई",
        "Bishnoi": "बिश्नोई",
        "Tilak Varma": "तिलक वर्मा",
        "Tilak": "तिलक",
        "Varma": "वर्मा",
        "Jitesh Sharma": "जितेश शर्मा",
        "Jitesh": "जितेश",
        "Shivam Dube": "शिवम दुबे",
        "Shivam": "शिवम",
        "Dube": "दुबे",
        "Ravi": "रवि",
        "Devdutt Padikkal": "देवदत्त पडिक्कल",
        "Devdutt": "देवदत्त",
        "Padikkal": "पडिक्कल",
        "Dhruv Jurel": "ध्रुव जुरेल",
        "Dhruv": "ध्रुव",
        "Jurel": "जुरेल",
        "Sarfaraz Khan": "सरफराज खान",
        "Sarfaraz": "सरफराज",
        "Rajat Patidar": "रजत पाटीदार",
        "Rajat": "रजत",
        "Patidar": "पाटीदार",
        "Akash Deep": "आकाश दीप",
        "Akash": "आकाश",
        
        // International cricketers
        "Glenn Maxwell": "ग्लेन मैक्सवेल",
        "Glenn": "ग्लेन",
        "Maxwell": "मैक्सवेल",
        "Mitchell Starc": "मिचेल स्टार्क",
        "Mitchell": "मिचेल",
        "Starc": "स्टार्क",
        "Pat Cummins": "पेट कमिंस",
        "Pat": "पेट",
        "Cummins": "कमिंस",
        "Travis Head": "ट्रैविस हेड",
        "Travis": "ट्रैविस",
        "Head": "हेड",
        "Steve Smith": "स्टीव स्मिथ",
        "Steve": "स्टीव",
        "Smith": "स्मिथ",
        "David Warner": "डेविड वॉर्नर",
        "David": "डेविड",
        "Warner": "वॉर्नर",
        "Marnus Labuschagne": "मार्नस लाबुशेन",
        "Marnus": "मार्नस",
        "Labuschagne": "लाबुशेन",
        "Josh Hazlewood": "जॉश हेजलवुड",
        "Josh": "जॉश",
        "Hazlewood": "हेजलवुड",
        "Adam Zampa": "एडम जम्पा",
        "Adam": "एडम",
        "Zampa": "जम्पा",
        "Jos Buttler": "जोस बटलर",
        "Jos": "जोस",
        "Buttler": "बटलर",
        "Joe Root": "जो रूट",
        "Joe": "जो",
        "Root": "रूट",
        "Ben Stokes": "बेन स्टोक्स",
        "Ben": "बेन",
        "Stokes": "स्टोक्स",
        "Harry Brook": "हैरी ब्रुक",
        "Harry": "हैरी",
        "Jonny Bairstow": "जॉनी बेयरस्टो",
        "Jonny": "जॉनी",
        "Bairstow": "बेयरस्टो",
        "Mark Wood": "मार्क वुड",
        "Mark": "मार्क",
        "Wood": "वुड",
        "Jofra Archer": "जोफ्रा आर्चर",
        "Jofra": "जोफ्रा",
        "Archer": "आर्चर",
        "Kane Williamson": "केन विलियमसन",
        "Kane": "केन",
        "Williamson": "विलियमसन",
        "Daryl Mitchell": "डेरिल मिचेल",
        "Daryl": "डेरिल",
        "Rachin Ravindra": "रचिन रविंद्र",
        "Rachin": "रचिन",
        "Trent Boult": "ट्रेंट बोल्ट",
        "Trent": "ट्रेंट",
        "Boult": "बोल्ट",
        "Tim Southee": "टिम साउदी",
        "Tim": "टिम",
        "Southee": "साउदी",
        "Mitchell Santner": "मिचेल सेंटनर",
        "Santner": "सेंटनर",
        "Quinton de Kock": "क्विंटन डी कॉक",
        "Quinton": "क्विंटन",
        "de Kock": "डी कॉक",
        "Kagiso Rabada": "कगिसो रबाडा",
        "Kagiso": "कगिसो",
        "Rabada": "रबाडा",
        "Heinrich Klaasen": "हेनरिक क्लासेन",
        "Heinrich": "हेनरिक",
        "Klaasen": "क्लासेन",
        "Aiden Markram": "एडेन मार्करम",
        "Aiden": "एडेन",
        "Markram": "मार्करम",
        "David Miller": "डेविड मिलर",
        "Miller": "मिलर",
        "Keshav Maharaj": "केशव महाराज",
        "Keshav": "केशव",
        "Maharaj": "महाराज",
        "Babar Azam": "बाबर आजम",
        "Babar": "बाबर",
        "Azam": "आजम",
        "Shaheen Afridi": "शाहीन अफरीदी",
        "Shaheen": "शाहीन",
        "Afridi": "अफरीदी",
        "Mohammad Rizwan": "मोहम्मद रिजवान",
        "Rizwan": "रिजवान",
        "Shadab Khan": "शादाब खान",
        "Shadab": "शादाब",
        "Naseem Shah": "नसीम शाह",
        "Naseem": "नसीम",
        "Shah": "शाह",
        "Rashid Khan": "राशिद खान",
        "Rashid": "राशिद",
        "Rahmanullah Gurbaz": "रहमानुल्लाह गुरबाज",
        "Rahmanullah": "रहमानुल्लाह",
        "Gurbaz": "गुरबाज",
        "Shakib Al Hasan": "शाकिब अल हसन",
        "Shakib": "शाकिब",
        "Al Hasan": "अल हसन",
    ]
}
