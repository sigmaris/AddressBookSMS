// Copyright (c) 2009 Anders Borum
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#include <stdio.h>   /* Standard input/output definitions */
#include <string.h>  /* String function definitions */
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */
#include <termios.h> /* POSIX terminal control definitions */
#include <assert.h>

#include <sys/errno.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>

#include <iostream>
#include <map>
#include <string>
#include <vector>
using namespace std;

#include "pdu.h"

// convert utf-8 to unicode - result is only valid if input string is
// valid utf-8.
static wstring from_utf8(string const& str) {
	vector<wchar_t> array;
	array.reserve(str.size());
	
	const unsigned len = str.size();
	unsigned k = 0;
	while(k < len) {
		unsigned c = (unsigned)str[k] & 0xff;
		
		// calculate total bytes for this character
		unsigned clen, n = c;
		if(c < 0x80) clen = 1; 
		else if((c & 0xe0) == 0xc0) { n &= ~0xe0; clen = 2; }
		else if((c & 0xf0) == 0xe0) { n &= ~0xf0; clen = 3; }
		else if((c & 0xf8) == 0xf0) { n &= ~0xf8; clen = 4; }
		else {
			// error condition, but we try to continue, assuming 
			// unrecognized byte was latin-1.
			clen = 1;
		}
		
		// stop if not room for character before string ends
		if(k + clen > len) break;
		
		// extract bits from extra characters
		for(unsigned i = 1; i < clen; ++i) {
			n = (n << 6) | ((unsigned)str[k+i] & 0x3f); 
		}
		
		array.push_back((wchar_t)n);
		k += clen;	
	}
	
	wchar_t const* ptr = &array[0];
	return wstring(ptr, ptr + array.size());
}

struct bitSequence {
	bitSequence(unsigned bit_size): 
    data((7 + bit_size) / 8, 0), pos(0) {}
	
	vector<unsigned char> data;
	unsigned pos;
	
	void set(unsigned bitpos, bool bit) {
		unsigned idx = bitpos / 8;
		assert(idx < data.size());
		
		unsigned char& byte = data[idx];
		if(bit) byte |= (1u << (bitpos % 8));
		else byte &= ~(1u << (bitpos % 8));
	}
	
	void add(bool bit) {
		set(pos, bit);
		pos += 1;
	} 
	
	void fill(bool bit) {
		while(pos < data.size()) add(bit);
	}
};

static void add_char(bitSequence& bits, unsigned c) {
	for(unsigned k = 0; k < 7; ++k) {
		bool b = (c & (1 << k)) != 0;
		bits.add(b);
	}
}

static string toString(std::vector<unsigned char> const& array) {
	char const* ptr = (const char*)&array[0];
	return std::string(ptr, ptr + array.size());
}
static string toString(std::vector<char> const& array) {
	char const* ptr = &array[0];
	return std::string(ptr, ptr + array.size());
}

// Pack N 7-bit chars into ceil(N*7/8) 8-bit chars, as described in
// GSM 3.38 subclause 6.1.2
static string packSeptets(string const& str, unsigned filler = 0, bool filler_data = false) {
	bitSequence bits(filler + 7 * str.size());

	// add filler bits
	for(unsigned i = 0; i < filler; ++i) bits.add(filler_data);	
	
    // add character data
	for(unsigned k = 0; k < str.size(); ++k) {
		unsigned c = (unsigned char)str[k];
		add_char(bits, c);
	}

	return ::toString(bits.data);
}

// [emi-spec page 12]
extern const wchar_t unicode_gsm_table[128] = {
	'@', L'£', '$', L'¥', L'è', L'é', L'ù', L'ì', L'ò', L'Ç', '\n', L'Ø',
	L'ø', '\r', L'Å', L'å', 
	L'\u0394', // greek capital delta
	'_', 
	L'\u03a6', // greek capital phi
	L'\u0393', // greek capital gamma
	L'\u039b', // greek capital lambda
	L'\u03a9', // greek capital omega
	L'\u03a0', // greek capital pi
	L'\u03a8', // greek capital psi
	L'\u03a3', // greek capital sigma
	L'\u0398', // greek capital theta
	L'\u039e', // greek capital xi
	'\0', // escape to extension table
		 // escaped characters 
		 //          '\f', '^', '{', '}', '\\', '[', '~', ']', '|', '',
	L'Æ', L'æ', L'ß', L'É', ' ', '!', '"', '#', L'¤', '%', '&', 
	'\'', '(', ')', '*', '+', ',', '-', '.', '/', '0', '1', 
	'2', '3', '4', '5', '6', '7', '8', '9', ':', ';', '<', 
	'=', '>', '?', L'¡', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 
	'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 
	'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', L'Ä', L'Ö', L'Ñ', 
	L'Ü', L'§', L'¿', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 
	'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 
	't', 'u', 'v', 'w', 'x', 'y', 'z', L'ä', L'ö', L'ñ', L'ü', 
	L'à'
};

static std::map<wchar_t, char> buildTable(wchar_t const* array, unsigned num) {
	map<wchar_t, char> m;
	for(unsigned i = 0; i < num; ++i) m[0xffffu & array[i]] = (char)i;
	return m;
}
static std::map<wchar_t, char> gsm_idx = buildTable(unicode_gsm_table, 128);

// Convert local character to GSM 7-bit alphabet throwing exception
// if char cannot be represented as single character.
static char convertUnicode2GSM(wchar_t c) throw(string) {			
	//c = unicode2gsm_compatible(c);
	if(gsm_idx.find(0xffffu & c) == gsm_idx.end()) return '?';
	return gsm_idx[c]; 
}

static bool only_gsm(wstring const& input) {
	for(unsigned i=0; i<input.size(); ++i) {
		if(gsm_idx.find(0xffffu & input[i]) == gsm_idx.end()) {
			return false;
		}
	}
	return true;
}

// Convert local character to GSM 7-bit alphabet throwing exception
// if any char cannot be represented as single character.
static string convertUnicode2GSM(wstring const& input) {
	string output(input.size(), ' ');
	for(unsigned i=0; i<input.size(); ++i) {
		output[i] = convertUnicode2GSM(input[i]);
	}
	return output;
}

static char toHexChar(unsigned n) {
	return n <= 9 ? (n + '0') : (n - 10 + 'A');
}

static string binary2hex(string const& str) {
	vector<char> array(str.size() * 2);
	
	for(unsigned i = 0; i < str.size(); ++i) {
		unsigned n = (unsigned char)str[i];
		array[2*i + 0] = toHexChar(n >> 4);
		array[2*i + 1] = toHexChar(n & 15);
	}
	
	return toString(array);
}

static string toHex(unsigned n, unsigned wid) {
	if(wid == 0) return "";
	
	wid -= 1;
	unsigned digit = (n >> (4 * wid)) & 15;
	char c = digit <= 9 ? '0' + digit : 'A' + digit - 10;
	
	return string(1, c) + toHex(n, wid);
}

static string toInt(unsigned n) {
	string digit(1, (n % 10) + '0');
	if(n <= 9) return digit;
	else return toInt(n / 10) + digit;
}

static char get_phone_char(char c) {
	if(c >= '0' && c <= '9') return c;
	switch(c) {
		case '*': return 'A';
		case '#': return 'B';
		case 'a': case 'A': 
			return 'C';
		case 'b': case 'B':		
			return 'E';
	}
	return 'F';
}

static string rawPhoneNumber(string& phone) {
	unsigned addrtype = 0x81;
	if(phone.size() > 0 && phone[0] == '+') {
		phone = phone.substr(1);
		addrtype = 0x91;
	}
	
	string out = toHex(addrtype, 2);
	for(unsigned k = 0; k < phone.size(); k += 2) {
		out += (k + 1 < phone.size() ? get_phone_char(phone[k+1]) : 'F');
		out += get_phone_char(phone[k]);
	}
	return out;
}

static string buildPhoneNumber(string phone) {
	string data = rawPhoneNumber(phone);
	return toHex(phone.size(), 2) + data;
}

static string convertUnicode2UCS2(wstring const& str) {
	vector<char> array;
	for(unsigned k = 0; k < str.size(); ++k) {
		unsigned n = 0xffffu & str[k];
		array.push_back(n >> 8);
		array.push_back(n & 255);
	}
	
	return toString(array);
}

static string buildPDU(char const* smsc,
				char const* phonenum,
				wstring const& msg,
				string const& udh,
				bool unicode,
				bool receipt) {
	//string latin1 = to_latin1(msg);
	string gsm = !unicode ? convertUnicode2GSM(msg) : "";
	string ucs = unicode ? convertUnicode2UCS2(msg) : "";
	
	// smsc-part of header
	string smsc_part = "00";
	if(strlen(smsc) > 0) {
		string str_smsc = smsc; // we need c++ string
		string p = rawPhoneNumber(str_smsc);
		smsc_part = toHex(p.size() / 2, 2) + p;
	}
	
	// header including phone number
	unsigned header = 0x01 | (udh.size() > 0 ? 0x40 : 0x00) 
	                       | (receipt ? 0x20 : 0x00);
	string pdu = smsc_part + toHex(header, 2) + "00" + buildPhoneNumber(phonenum);
	
	// validity period and actual message
	unsigned udh_bits = 0, filler = 0;
	unsigned divider = unicode ? 8 : 7;
	if(udh.size() > 0) {
		udh_bits = 8 * (1 + udh.size() / 2);

		if(udh_bits % divider != 0) filler = divider - (udh_bits % divider);
		udh_bits += filler; //round up to multiple of divider
		assert(udh_bits % divider == 0);
	}
	unsigned total_size = gsm.size() + ucs.size() + (udh_bits / divider);
	string packed = unicode ? ucs : packSeptets(gsm, filler, false);
	
	unsigned dcs = unicode ? 0x08 : 0x00;
	pdu += "00" + toHex(dcs, 2) + toHex(total_size, 2);
	if(udh.size() > 0) pdu += toHex(udh.size() / 2, 2) + udh;
	pdu += binary2hex(packed);
	
	return pdu;
}

int countPDUs(char const* utf8_message) {
	wstring message = from_utf8(utf8_message);
    const bool unicode = !only_gsm(message);
    const unsigned sms_limit = unicode ? 70 : 160;
	
	unsigned len = message.length();
	if(len <= sms_limit) return 1;
	
	// concat header takes 6 bytes, which could store 48 bits or
	// almost 7 septets. We have room for seven less gsm characters
	// or 3 less unicode characters.
	unsigned capacity = sms_limit - (unicode ? 3 : 7);	
	return (len + capacity - 1) / capacity;
}

vector<string> buildPDUs(char const* smsc, char const* phone_number,
						 char const* utf8_message, bool receipt) {
	wstring message = from_utf8(utf8_message);
    const bool unicode = !only_gsm(message);
    const unsigned sms_limit = unicode ? 70 : 160;

	unsigned len = message.length();
	vector<wstring> ud_chunk;
	vector<string> udh_chunk;	
	if(len <= sms_limit) {
		ud_chunk.push_back(message);
		udh_chunk.push_back("");
	} else {
		// concat header takes 6 bytes, which could store 48 bits or
		// almost 7 septets. We have room for seven less gsm characters
		// or 3 less unicode characters.
		unsigned capacity = sms_limit - (unicode ? 3 : 7);
		
		sranddev();
		unsigned seq = rand() % 256;
		unsigned num = (message.length() + capacity - 1) / capacity; 
		unsigned pos = 1;
		while(pos == 1 || message.length() > 0) {
			unsigned len = capacity;
			if(len > message.length()) len = message.length();
			
			string udh = "0003" + toHex(seq, 2) + toHex(num, 2) + toHex(pos, 2);
			udh_chunk.push_back(udh);
			ud_chunk.push_back(message.substr(0, len));
			
			message = message.substr(len);
			pos += 1;
		}
	}
			  
	vector<string> pdu;
	for(unsigned k = 0; k < ud_chunk.size(); ++k) {
		pdu.push_back(buildPDU(smsc, phone_number, ud_chunk[k], udh_chunk[k], unicode, receipt));
	}	
	return pdu;
}
