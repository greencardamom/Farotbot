<?php

// Cyberpower678 May 2017

// The MIT License (MIT)
//
// Copyright (c) 2017 by User:Cyberpower678 (at en.wikipedia.org)
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

// Will generate that example header:

//   Authorization: OAuth oauth_consumer_key="ad8e33572688dd300d2b726bee409f5d", oauth_token="147e94d316131e029a70db90bda94940", oauth_version="1.0", oauth_nonce="8fdb2ae28cf869a9e876e7df7b660d61", oauth_timestamp="1495913787", oauth_signature_method="HMAC-SHA1", oauth_signature="M0my3w8VlP44GaksVIyjSWhY8dg%3D"



// To call it from the CLI, use

//   php MWOAuthGenerateHeader.php <consumer key> <consumer secret> <access token> <access secret> <destination URL>

// It will spit out FAIL if the parameters aren't passed.

// I haven't tested it, but I took it straight from my OAuth engine, so it should work.

// This also DOESN'T support RSA keys. You need to remove yours to get it to work.

// If successful, it should echo back only that header string which you just need to add to the header of your request.



if( !isset( $argv[1] ) || !isset( $argv[2] ) || !isset( $argv[3] ) || !isset( $argv[4] ) || !isset( $argv[5] ) ) die( "FAIL" );

define( 'CONSUMERKEY', $argv[1] );

define( 'CONSUMERSECRET', $argv[2] );

define( 'ACCESSTOKEN', $argv[3] );

define( 'ACCESSSECRET', $argv[4] );



echo generateOAuthHeader( 'GET', $argv[5] );



function generateOAuthHeader( $method = 'GET', $url ) {

	$headerArr = [

		// OAuth information

		'oauth_consumer_key'     => CONSUMERKEY,

		'oauth_token'            => ACCESSTOKEN,

		'oauth_version'          => '1.0',

		'oauth_nonce'            => md5( microtime() . mt_rand() ),

		'oauth_timestamp'        => time(),



		// We're using secret key signatures here.

		'oauth_signature_method' => 'HMAC-SHA1',

	];

	$signature = generateSignature( $method, $url, $headerArr );

	$headerArr['oauth_signature'] = $signature;



	$header = [];

	foreach( $headerArr as $k => $v ) {

		$header[] = rawurlencode( $k ) . '="' . rawurlencode( $v ) . '"';

	}

	$header = 'Authorization: OAuth ' . join( ', ', $header );

	unset( $headerArr );



	return $header;

}



function generateSignature( $method, $url, $params = [] ) {

	$parts = parse_url( $url );



	// We need to normalize the endpoint URL

	$scheme = isset( $parts['scheme'] ) ? $parts['scheme'] : 'http';

	$host = isset( $parts['host'] ) ? $parts['host'] : '';

	$port = isset( $parts['port'] ) ? $parts['port'] : ( $scheme == 'https' ? '443' : '80' );

	$path = isset( $parts['path'] ) ? $parts['path'] : '';

	if( ( $scheme == 'https' && $port != '443' ) ||

	    ( $scheme == 'http' && $port != '80' )

	) {

		// Only include the port if it's not the default

		$host = "$host:$port";

	}



	// Also the parameters

	$pairs = [];

	parse_str( isset( $parts['query'] ) ? $parts['query'] : '', $query );

	$query += $params;

	unset( $query['oauth_signature'] );

	if( $query ) {

		$query = array_combine(

		// rawurlencode follows RFC 3986 since PHP 5.3

			array_map( 'rawurlencode', array_keys( $query ) ),

			array_map( 'rawurlencode', array_values( $query ) )

		);

		ksort( $query, SORT_STRING );

		foreach( $query as $k => $v ) {

			$pairs[] = "$k=$v";

		}

	}



	$toSign = rawurlencode( strtoupper( $method ) ) . '&' .

	          rawurlencode( "$scheme://$host$path" ) . '&' .

	          rawurlencode( join( '&', $pairs ) );



//        echo $toSign;



	$key = rawurlencode( CONSUMERSECRET ) . '&' . rawurlencode( ACCESSSECRET );



	return base64_encode( hash_hmac( 'sha1', $toSign, $key, true ) );

}


