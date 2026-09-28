//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Swift-native implementation of Cox's fast unrounded scaling algorithm for
// floating-point parsing and shortest-width printing (2026), described at:
// https://research.swtch.com/fp
//
// In lieu of an 'unrounded' type with two trailing bits for correct rounding,
// we perform the relevant bit shifts inline.
//
//===----------------------------------------------------------------------===//

// 192-bit mantissas of powers of 10, rounded up, scaled so the highest bit is
// always set, represented by the high 64-bit limb rounded up and the lower
// 128-bit limbs negated (i.e., `(high << 128) - (low << 64) - lowest`).
//
// Cox's proof of correctness requires error ε < 1 ulp, so this table can't be
// replaced by a product of coarse and fine values.
private let _table: [_ of (high: UInt64, low: UInt64, lowest: UInt64)] = [
    (0x82ef85133de648c5, 0x6567b28c2418dd04, 0xa390bb5c655c633e), // 1e-149 * 2**686
    (0xa3ab66580d5fdaf6, 0x3ec19f2f2d1f1445, 0xcc74ea337eb37c0d), // 1e-148 * 2**683
    (0xcc963fee10b7d1b4, 0xce7206faf866d957, 0x3f9224c05e605b10), // 1e-147 * 2**680
    (0xffbbcfe994e5c620, 0x020e88b9b6808fad, 0x0f76adf075f871d5), // 1e-146 * 2**677
    (0x9fd561f1fd0f9bd4, 0x01491574121059cc, 0x29aa2cb649bb4725), // 1e-145 * 2**673
    (0xc7caba6e7c5382c9, 0x019b5ad11694703f, 0x3414b7e3dc2a18ee), // 1e-144 * 2**670
    (0xf9bd690a1b68637c, 0xc20231855c398c4f, 0x0119e5dcd3349f2a), // 1e-143 * 2**667
    (0x9c1661a651213e2e, 0xf9415ef359a3f7b1, 0x60b02faa0400e37a), // 1e-142 * 2**663
    (0xc31bfa0fe5698db9, 0xb791b6b0300cf59d, 0xb8dc3b9485011c58), // 1e-141 * 2**660
    (0xf3e2f893dec3f127, 0xa576245c3c103305, 0x27134a79a641636f), // 1e-140 * 2**657
    (0x986ddb5c6b3a76b8, 0x0769d6b9a58a1fe3, 0x386c0e8c07e8de25), // 1e-139 * 2**653
    (0xbe89523386091466, 0x09444c680eeca7dc, 0x0687122f09e315ae), // 1e-138 * 2**650
    (0xee2ba6c0678b5980, 0x8b955f8212a7d1d3, 0x0828d6bacc5bdb1a), // 1e-137 * 2**647
    (0x94db483840b717f0, 0x573d5bb14ba8e323, 0xe5198634bfb968f0), // 1e-136 * 2**643
    (0xba121a4650e4ddec, 0x6d0cb29d9e931bec, 0xde5fe7c1efa7c32c), // 1e-135 * 2**640
    (0xe896a0d7e51e1567, 0x884fdf450637e2e8, 0x15f7e1b26b91b3f8), // 1e-134 * 2**637
    (0x915e2486ef32cd61, 0xf531eb8b23e2edd1, 0x0dbaed0f833b107b), // 1e-133 * 2**633
    (0xb5b5ada8aaff80b9, 0xf27e666decdba945, 0x5129a8536409d499), // 1e-132 * 2**630
    (0xe3231912d5bf60e7, 0xef1e000968129396, 0xa57412683d0c49c0), // 1e-131 * 2**627
    (0x8df5efabc5979c90, 0x3572c005e10b9c3e, 0x27688b812627ae18), // 1e-130 * 2**623
    (0xb1736b96b6fd83b4, 0x42cf7007594e834d, 0xb142ae616fb1999e), // 1e-129 * 2**620
    (0xddd0467c64bce4a1, 0x53834c092fa22421, 0x1d9359f9cb9e0005), // 1e-128 * 2**617
    (0x8aa22c0dbef60ee5, 0x94320f85bdc55694, 0xb27c183c1f42c003), // 1e-127 * 2**613
    (0xad4ab7112eb3929e, 0x793e93672d36ac39, 0xdf1b1e4b27137004), // 1e-126 * 2**610
    (0xd89d64d57a607745, 0x178e3840f8845748, 0x56e1e5ddf0d84c05), // 1e-125 * 2**607
    (0x87625f056c7c4a8c, 0xeeb8e3289b52b68d, 0x364d2faab6872f83), // 1e-124 * 2**603
    (0xa93af6c6c79b5d2e, 0x2a671bf2c2276430, 0x83e07b956428fb64), // 1e-123 * 2**600
    (0xd389b4787982347a, 0xb500e2ef72b13d3c, 0xa4d89a7abd333a3d), // 1e-122 * 2**597
    (0x843610cb4bf160cc, 0x31208dd5a7aec645, 0xe707608cb6400466), // 1e-121 * 2**593
    (0xa54394fe1eedb8ff, 0x3d68b14b119a77d7, 0x60c938afe3d0057f), // 1e-120 * 2**590
    (0xce947a3da6a9273f, 0x8cc2dd9dd60115cd, 0x38fb86dbdcc406df), // 1e-119 * 2**587
    (0x811ccc668829b888, 0xf7f9ca82a5c0ada0, 0x439d344969fa844b), // 1e-118 * 2**583
    (0xa163ff802a3426a9, 0x35f83d234f30d908, 0x5484815bc479255e), // 1e-117 * 2**580
    (0xc9bcff6034c13053, 0x03764c6c22fd0f4a, 0x69a5a1b2b5976eb6), // 1e-116 * 2**577
    (0xfc2c3f3841f17c68, 0x4453df872bbc531d, 0x040f0a1f62fd4a64), // 1e-115 * 2**574
    (0x9d9ba7832936edc1, 0x2ab46bb47b55b3f2, 0x228966539dde4e7e), // 1e-114 * 2**570
    (0xc5029163f384a932, 0xf56186a19a2b20ee, 0xab2bbfe88555e21e), // 1e-113 * 2**567
    (0xf64335bcf065d37e, 0xb2b9e84a00b5e92a, 0x55f6afe2a6ab5aa6), // 1e-112 * 2**564
    (0x99ea0196163fa42f, 0xafb4312e4071b1ba, 0x75ba2deda82b18a7), // 1e-111 * 2**560
    (0xc06481fb9bcf8d3a, 0x1ba13d79d08e1e29, 0x1328b9691235ded1), // 1e-110 * 2**557
    (0xf07da27a82c37089, 0xa2898cd844b1a5b3, 0x57f2e7c356c35686), // 1e-109 * 2**554
    (0x964e858c91ba2656, 0xc595f8072aef0790, 0x16f7d0da163a1613), // 1e-108 * 2**550
    (0xbbe226efb628afeb, 0x76fb7608f5aac974, 0x1cb5c5109bc89b98), // 1e-107 * 2**547
    (0xeadab0aba3b2dbe6, 0xd4ba538b33157bd1, 0x23e33654c2bac27f), // 1e-106 * 2**544
    (0x92c8ae6b464fc970, 0xc4f47436ffed6d62, 0xb66e01f4f9b4b98f), // 1e-105 * 2**540
    (0xb77ada0617e3bbcc, 0xf6319144bfe8c8bb, 0x640982723821e7f3), // 1e-104 * 2**537
    (0xe55990879ddcaabe, 0x33bdf595efe2faea, 0x3d0be30ec62a61f0), // 1e-103 * 2**534
    (0x8f57fa54c2a9eab7, 0x6056b97db5eddcd2, 0x66276de93bda7d36), // 1e-102 * 2**530
    (0xb32df8e9f3546565, 0xb86c67dd23695406, 0xffb149638ad11c83), // 1e-101 * 2**527
    (0xdff9772470297ebe, 0xa68781d46c43a908, 0xbf9d9bbc6d8563a4), // 1e-100 * 2**524
    (0x8bfbea76c619ef37, 0xa814b124c3aa49a5, 0x77c28155c4735e46), // 1e-99 * 2**520
    (0xaefae51477a06b04, 0x1219dd6df494dc0e, 0xd5b321ab359035d8), // 1e-98 * 2**517
    (0xdab99e59958885c5, 0x16a054c971ba1312, 0x8b1fea1602f4434e), // 1e-97 * 2**514
    (0x88b402f7fd75539c, 0xee2434fde7144beb, 0x96f3f24dc1d8aa11), // 1e-96 * 2**510
    (0xaae103b5fcd2a882, 0x29ad423d60d95ee6, 0x7cb0eee1324ed495), // 1e-95 * 2**507
    (0xd59944a37c0752a3, 0xb41892ccb90fb6a0, 0x1bdd2a997ee289ba), // 1e-94 * 2**504
    (0x857fcae62d8493a6, 0x908f5bbff3a9d224, 0x116a3a9fef4d9614), // 1e-93 * 2**500
    (0xa6dfbd9fb8e5b88f, 0x34b332aff09446ad, 0x15c4c947eb20fb99), // 1e-92 * 2**497
    (0xd097ad07a71f26b3, 0x81dfff5becb95858, 0x5b35fb99e5e93a80), // 1e-91 * 2**494
    (0x825ecc24c8737830, 0x712bff9973f3d737, 0x3901bd402fb1c490), // 1e-90 * 2**490
    (0xa2f67f2dfa90563c, 0x8d76ff7fd0f0cd05, 0x07422c903b9e35b4), // 1e-89 * 2**487
    (0xcbb41ef979346bcb, 0xb0d4bf5fc52d0046, 0x4912b7b44a85c321), // 1e-88 * 2**484
    (0xfea126b7d78186bd, 0x1d09ef37b6784057, 0xdb5765a15d2733e9), // 1e-87 * 2**481
    (0x9f24b832e6b0f437, 0xf2263582d20b2836, 0xe9169f84da388072), // 1e-86 * 2**477
    (0xc6ede63fa05d3144, 0x6eafc2e3868df244, 0xa35c476610c6a08e), // 1e-85 * 2**474
    (0xf8a95fcf88747d95, 0x8a5bb39c68316ed5, 0xcc33593f94f848b2), // 1e-84 * 2**471
    (0x9b69dbe1b548ce7d, 0x36795041c11ee545, 0x9fa017c7bd1b2d6f), // 1e-83 * 2**467
    (0xc24452da229b021c, 0x0417a45231669e97, 0x07881db9ac61f8cb), // 1e-82 * 2**464
    (0xf2d56790ab41c2a3, 0x051d8d66bdc0463c, 0xc96a2528177a76fe), // 1e-81 * 2**461
    (0x97c560ba6b0919a6, 0x2332786036982be5, 0xfde257390eac8a5e), // 1e-80 * 2**457
    (0xbdb6b8e905cb6010, 0xabff1678443e36df, 0x7d5aed075257acf6), // 1e-79 * 2**454
    (0xed246723473e3814, 0xd6fedc16554dc497, 0x5cb1a84926ed9834), // 1e-78 * 2**451
    (0x9436c0760c86e30c, 0x065f498df5509ade, 0x99ef092db8547f20), // 1e-77 * 2**447
    (0xb94470938fa89bcf, 0x07f71bf172a4c196, 0x406acb7926699ee8), // 1e-76 * 2**444
    (0xe7958cb87392c2c3, 0x49f4e2edcf4df1fb, 0xd0857e57700406a2), // 1e-75 * 2**441
    (0x90bd77f3483bb9ba, 0x4e390dd4a190b73d, 0x62536ef6a6028425), // 1e-74 * 2**437
    (0xb4ecd5f01a4aa829, 0xe1c75149c9f4e50c, 0xbae84ab44f83252f), // 1e-73 * 2**434
    (0xe2280b6c20dd5233, 0xda39259c3c721e4f, 0xe9a25d616363ee7b), // 1e-72 * 2**431
    (0x8d590723948a5360, 0xa863b781a5c752f1, 0xf2057a5cde1e750c), // 1e-71 * 2**427
    (0xb0af48ec79ace838, 0xd27ca5620f3927ae, 0x6e86d8f415a61250), // 1e-70 * 2**424
    (0xdcdb1b2798182245, 0x071bceba9307719a, 0x0a288f311b0f96e4), // 1e-69 * 2**421
    (0x8a08f0f8bf0f156c, 0xe47161349be4a700, 0x4659597eb0e9be4e), // 1e-68 * 2**417
    (0xac8b2d36eed2dac6, 0x1d8db981c2ddd0c0, 0x57efafde5d242de2), // 1e-67 * 2**414
    (0xd7adf884aa879178, 0xa4f127e2339544f0, 0x6deb9bd5f46d395a), // 1e-66 * 2**411
    (0x86ccbb52ea94baeb, 0x6716b8ed603d4b16, 0x44b34165b8c443d8), // 1e-65 * 2**407
    (0xa87fea27a539e9a6, 0xc0dc6728b84c9ddb, 0xd5e011bf26f554ce), // 1e-64 * 2**404
    (0xd29fe4b18e88640f, 0x711380f2e65fc552, 0xcb58162ef0b2aa02), // 1e-63 * 2**401
    (0x83a3eeeef9153e8a, 0xe6ac3097cffbdb53, 0xbf170ddd566faa41), // 1e-62 * 2**397
    (0xa48ceaaab75a8e2c, 0xa0573cbdc3fad228, 0xaedcd154ac0b94d2), // 1e-61 * 2**394
    (0xcdb02555653131b7, 0xc86d0bed34f986b2, 0xda9405a9d70e7a06), // 1e-60 * 2**391
    (0x808e17555f3ebf12, 0x1d442774411bf42f, 0xc89c838a26690c44), // 1e-59 * 2**387
    (0xa0b19d2ab70e6ed7, 0xa49531515162f13b, 0xbac3a46cb0034f55), // 1e-58 * 2**384
    (0xc8de047564d20a8c, 0x0dba7da5a5bbad8a, 0xa9748d87dc04232a), // 1e-57 * 2**381
    (0xfb158592be068d2f, 0x11291d0f0f2a98ed, 0x53d1b0e9d3052bf5), // 1e-56 * 2**378
    (0x9ced737bb6c4183e, 0xaab9b229697a9f94, 0x54630e9223e33b79), // 1e-55 * 2**374
    (0xc428d05aa4751e4d, 0x55681eb3c3d94779, 0x697bd236acdc0a57), // 1e-54 * 2**371
    (0xf53304714d9265e0, 0x2ac22660b4cf9957, 0xc3dac6c458130ced), // 1e-53 * 2**368
    (0x993fe2c6d07b7fac, 0x1ab957fc7101bfd6, 0xda68bc3ab70be814), // 1e-52 * 2**364
    (0xbf8fdb78849a5f97, 0x2167adfb8d422fcc, 0x9102eb4964cee219), // 1e-51 * 2**361
    (0xef73d256a5c0f77d, 0x69c1997a7092bbbf, 0xb543a61bbe029a9f), // 1e-50 * 2**358
    (0x95a8637627989aae, 0x2218ffec865bb557, 0xd14a47d156c1a0a3), // 1e-49 * 2**354
    (0xbb127c53b17ec15a, 0xaa9f3fe7a7f2a2ad, 0xc59cd9c5ac7208cc), // 1e-48 * 2**351
    (0xe9d71b689dde71b0, 0x55470fe191ef4b59, 0x37041037178e8b00), // 1e-47 * 2**348
    (0x9226712162ab070e, 0x354c69ecfb358f17, 0xc2628a226eb916e0), // 1e-46 * 2**344
    (0xb6b00d69bb55c8d2, 0xc29f84683a02f2dd, 0xb2fb2cab0a675c98), // 1e-45 * 2**341
    (0xe45c10c42a2b3b06, 0x734765824883af95, 0x1fb9f7d5cd0133be), // 1e-44 * 2**338
    (0x8eb98a7a9a5b04e4, 0x880c9f716d524dbd, 0x33d43ae5a020c056), // 1e-43 * 2**334
    (0xb267ed1940f1c61d, 0xaa0fc74dc8a6e12c, 0x80c9499f0828f06c), // 1e-42 * 2**331
    (0xdf01e85f912e37a4, 0x9493b9213ad09977, 0xa0fb9c06ca332c87), // 1e-41 * 2**328
    (0x8b61313bbabce2c7, 0xdcdc53b4c4c25fea, 0xc49d41843e5ffbd4), // 1e-40 * 2**324
    (0xae397d8aa96c1b78, 0x541368a1f5f2f7e5, 0x75c491e54df7fac9), // 1e-39 * 2**321
    (0xd9c7dced53c72256, 0x691842ca736fb5de, 0xd335b65ea175f97c), // 1e-38 * 2**318
    (0x881cea14545c7576, 0x81af29be8825d1ab, 0x440191fb24e9bbed), // 1e-37 * 2**314
    (0xaa242499697392d3, 0x221af42e2a2f4616, 0x1501f679ee242ae9), // 1e-36 * 2**311
    (0xd4ad2dbfc3d07788, 0x6aa1b139b4bb179b, 0x9a42741869ad35a3), // 1e-35 * 2**308
    (0x84ec3c97da624ab5, 0x42a50ec410f4eec1, 0x4069888f420c4186), // 1e-34 * 2**304
    (0xa6274bbdd0fadd62, 0x134e527515322a71, 0x9083eab3128f51e7), // 1e-33 * 2**301
    (0xcfb11ead453994bb, 0x9821e7125a7eb50d, 0xf4a4e55fd7332661), // 1e-32 * 2**298
    (0x81ceb32c4b43fcf5, 0x7f15306b788f3128, 0xb8e70f5be67ff7fd), // 1e-31 * 2**294
    (0xa2425ff75e14fc32, 0x5eda7c8656b2fd72, 0xe720d332e01ff5fc), // 1e-30 * 2**291
    (0xcad2f7f5359a3b3f, 0xf6911ba7ec5fbccf, 0xa0e907ff9827f37b), // 1e-29 * 2**288
    (0xfd87b5f28300ca0e, 0x74356291e777ac03, 0x892349ff7e31f05a), // 1e-28 * 2**285
    (0x9e74d1b791e07e49, 0x88a15d9b30aacb82, 0x35b60e3faedf3638), // 1e-27 * 2**281
    (0xc612062576589ddb, 0x6ac9b501fcd57e62, 0xc32391cf9a9703c6), // 1e-26 * 2**278
    (0xf79687aed3eec552, 0xc57c22427c0addfb, 0x73ec7643813cc4b8), // 1e-25 * 2**275
    (0x9abe14cd44753b53, 0x3b6d95698d86cabd, 0x2873c9ea30c5faf3), // 1e-24 * 2**271
    (0xc16d9a0095928a28, 0x8a48fac3f0e87d6c, 0x7290bc64bcf779af), // 1e-23 * 2**268
    (0xf1c90080baf72cb2, 0xacdb3974ed229cc7, 0x8f34eb7dec35581b), // 1e-22 * 2**265
    (0x971da05074da7bef, 0x2c0903e91435a1fc, 0xb981132eb3a15711), // 1e-21 * 2**261
    (0xbce5086492111aeb, 0x770b44e359430a7b, 0xe7e157fa6089acd5), // 1e-20 * 2**258
    (0xec1e4a7db69561a6, 0xd4ce161c2f93cd1a, 0xe1d9adf8f8ac180b), // 1e-19 * 2**255
    (0x9392ee8e921d5d08, 0xc500cdd19dbc6030, 0xcd280cbb9b6b8f06), // 1e-18 * 2**251
    (0xb877aa3236a4b44a, 0xf6410146052b783d, 0x00720fea824672c8), // 1e-17 * 2**248
    (0xe69594bec44de15c, 0xb3d141978676564c, 0x408e93e522d80f7a), // 1e-16 * 2**245
    (0x901d7cf73ab0acda, 0xf062c8feb409f5ef, 0xa8591c6f35c709ac), // 1e-15 * 2**241
    (0xb424dc35095cd810, 0xac7b7b3e610c736b, 0x926f638b0338cc17), // 1e-14 * 2**238
    (0xe12e13424bb40e14, 0xd79a5a0df94f9046, 0x770b3c6dc406ff1d), // 1e-13 * 2**235
    (0x8cbccc096f5088cc, 0x06c07848bbd1ba2c, 0x0a6705c49a845f72), // 1e-12 * 2**231
    (0xafebff0bcb24aaff, 0x0870965aeac628b7, 0x0d00c735c125774f), // 1e-11 * 2**228
    (0xdbe6fecebdedd5bf, 0x4a8cbbf1a577b2e4, 0xd040f903316ed523), // 1e-10 * 2**225
    (0x89705f4136b4a598, 0xce97f577076acfcf, 0x02289ba1fee54536), // 1e-9 * 2**221
    (0xabcc77118461cefd, 0x023df2d4c94583c2, 0xc2b2c28a7e9e9683), // 1e-8 * 2**218
    (0xd6bf94d5e57a42bd, 0xc2cd6f89fb96e4b3, 0x735f732d1e463c24), // 1e-7 * 2**215
    (0x8637bd05af6c69b6, 0x59c065b63d3e4ef0, 0x281ba7fc32ebe596), // 1e-6 * 2**211
    (0xa7c5ac471b478424, 0xf0307f23cc8de2ac, 0x322291fb3fa6defc), // 1e-5 * 2**208
    (0xd1b71758e219652c, 0x2c3c9eecbfb15b57, 0x3eab367a0f9096bb), // 1e-4 * 2**205
    (0x83126e978d4fdf3c, 0x9ba5e353f7ced916, 0x872b020c49ba5e35), // 1e-3 * 2**201
    (0xa3d70a3d70a3d70b, 0xc28f5c28f5c28f5c, 0x28f5c28f5c28f5c2), // 1e-2 * 2**198
    (0xcccccccccccccccd, 0x3333333333333333, 0x3333333333333333), // 1e-1 * 2**195
    (0x8000000000000000, 0x0000000000000000, 0x0000000000000000), // 1e0 * 2**191
    (0xa000000000000000, 0x0000000000000000, 0x0000000000000000), // 1e1 * 2**188
    (0xc800000000000000, 0x0000000000000000, 0x0000000000000000), // 1e2 * 2**185
    (0xfa00000000000000, 0x0000000000000000, 0x0000000000000000), // 1e3 * 2**182
    (0x9c40000000000000, 0x0000000000000000, 0x0000000000000000), // 1e4 * 2**178
    (0xc350000000000000, 0x0000000000000000, 0x0000000000000000), // 1e5 * 2**175
    (0xf424000000000000, 0x0000000000000000, 0x0000000000000000), // 1e6 * 2**172
    (0x9896800000000000, 0x0000000000000000, 0x0000000000000000), // 1e7 * 2**168
    (0xbebc200000000000, 0x0000000000000000, 0x0000000000000000), // 1e8 * 2**165
    (0xee6b280000000000, 0x0000000000000000, 0x0000000000000000), // 1e9 * 2**162
    (0x9502f90000000000, 0x0000000000000000, 0x0000000000000000), // 1e10 * 2**158
    (0xba43b74000000000, 0x0000000000000000, 0x0000000000000000), // 1e11 * 2**155
    (0xe8d4a51000000000, 0x0000000000000000, 0x0000000000000000), // 1e12 * 2**152
    (0x9184e72a00000000, 0x0000000000000000, 0x0000000000000000), // 1e13 * 2**148
    (0xb5e620f480000000, 0x0000000000000000, 0x0000000000000000), // 1e14 * 2**145
    (0xe35fa931a0000000, 0x0000000000000000, 0x0000000000000000), // 1e15 * 2**142
    (0x8e1bc9bf04000000, 0x0000000000000000, 0x0000000000000000), // 1e16 * 2**138
    (0xb1a2bc2ec5000000, 0x0000000000000000, 0x0000000000000000), // 1e17 * 2**135
    (0xde0b6b3a76400000, 0x0000000000000000, 0x0000000000000000), // 1e18 * 2**132
    (0x8ac7230489e80000, 0x0000000000000000, 0x0000000000000000), // 1e19 * 2**128
    (0xad78ebc5ac620000, 0x0000000000000000, 0x0000000000000000), // 1e20 * 2**125
    (0xd8d726b7177a8000, 0x0000000000000000, 0x0000000000000000), // 1e21 * 2**122
    (0x878678326eac9000, 0x0000000000000000, 0x0000000000000000), // 1e22 * 2**118
    (0xa968163f0a57b400, 0x0000000000000000, 0x0000000000000000), // 1e23 * 2**115
    (0xd3c21bcecceda100, 0x0000000000000000, 0x0000000000000000), // 1e24 * 2**112
    (0x84595161401484a0, 0x0000000000000000, 0x0000000000000000), // 1e25 * 2**108
    (0xa56fa5b99019a5c8, 0x0000000000000000, 0x0000000000000000), // 1e26 * 2**105
    (0xcecb8f27f4200f3a, 0x0000000000000000, 0x0000000000000000), // 1e27 * 2**102
    (0x813f3978f8940985, 0xc000000000000000, 0x0000000000000000), // 1e28 * 2**98
    (0xa18f07d736b90be6, 0xb000000000000000, 0x0000000000000000), // 1e29 * 2**95
    (0xc9f2c9cd04674edf, 0x5c00000000000000, 0x0000000000000000), // 1e30 * 2**92
    (0xfc6f7c4045812297, 0xb300000000000000, 0x0000000000000000), // 1e31 * 2**89
    (0x9dc5ada82b70b59e, 0x0fe0000000000000, 0x0000000000000000), // 1e32 * 2**85
    (0xc5371912364ce306, 0x93d8000000000000, 0x0000000000000000), // 1e33 * 2**82
    (0xf684df56c3e01bc7, 0x38ce000000000000, 0x0000000000000000), // 1e34 * 2**79
    (0x9a130b963a6c115d, 0xc380c00000000000, 0x0000000000000000), // 1e35 * 2**75
    (0xc097ce7bc90715b4, 0xb460f00000000000, 0x0000000000000000), // 1e36 * 2**72
    (0xf0bdc21abb48db21, 0xe1792c0000000000, 0x0000000000000000), // 1e37 * 2**69
    (0x96769950b50d88f5, 0xecebbb8000000000, 0x0000000000000000), // 1e38 * 2**65
    (0xbc143fa4e250eb32, 0xe826aa6000000000, 0x0000000000000000), // 1e39 * 2**62
    (0xeb194f8e1ae525fe, 0xa23054f800000000, 0x0000000000000000), // 1e40 * 2**59
    (0x92efd1b8d0cf37bf, 0xa55e351b00000000, 0x0000000000000000), // 1e41 * 2**55
    (0xb7abc627050305ae, 0x0eb5c261c0000000, 0x0000000000000000), // 1e42 * 2**52
    (0xe596b7b0c643c71a, 0x926332fa30000000, 0x0000000000000000), // 1e43 * 2**49
    (0x8f7e32ce7bea5c70, 0x1b7dffdc5e000000, 0x0000000000000000), // 1e44 * 2**45
    (0xb35dbf821ae4f38c, 0x225d7fd375800000, 0x0000000000000000), // 1e45 * 2**42
    (0xe0352f62a19e306f, 0x2af4dfc852e00000, 0x0000000000000000), // 1e46 * 2**39
    (0x8c213d9da502de46, 0xbad90bdd33cc0000, 0x0000000000000000), // 1e47 * 2**35
    (0xaf298d050e4395d7, 0x698f4ed480bf0000, 0x0000000000000000), // 1e48 * 2**32
    (0xdaf3f04651d47b4d, 0xc3f32289a0eec000, 0x0000000000000000), // 1e49 * 2**29
    (0x88d8762bf324cd10, 0x5a77f59604953800, 0x0000000000000000), // 1e50 * 2**25
    (0xab0e93b6efee0054, 0x7115f2fb85ba8600, 0x0000000000000000), // 1e51 * 2**22
    (0xd5d238a4abe98069, 0x8d5b6fba67292780, 0x0000000000000000), // 1e52 * 2**19
    (0x85a36366eb71f042, 0xb85925d48079b8b0, 0x0000000000000000), // 1e53 * 2**15
    (0xa70c3c40a64e6c52, 0x666f6f49a09826dc, 0x0000000000000000), // 1e54 * 2**12
    (0xd0cf4b50cfe20766, 0x000b4b1c08be3093, 0x0000000000000000), // 1e55 * 2**9
    (0x82818f1281ed44a0, 0x40070ef18576de5b, 0xe000000000000000), // 1e56 * 2**5
    (0xa321f2d7226895c8, 0x5008d2ade6d495f2, 0xd800000000000000), // 1e57 * 2**2
    (0xcbea6f8ceb02bb3a, 0x640b07596089bb6f, 0x8e00000000000000), // 1e58 * 2**-1
    (0xfee50b7025c36a09, 0xfd0dc92fb8ac2a4b, 0x7180000000000000), // 1e59 * 2**-4
    (0x9f4f2726179a2246, 0xfe289dbdd36b9a6f, 0x26f0000000000000), // 1e60 * 2**-8
    (0xc722f0ef9d80aad7, 0xbdb2c52d4846810a, 0xf0ac000000000000), // 1e61 * 2**-11
    (0xf8ebad2b84e0d58c, 0x2d1f76789a58214d, 0xacd7000000000000), // 1e62 * 2**-14
    (0x9b934c3b330c8578, 0x9c33aa0b607714d0, 0x8c06600000000000), // 1e63 * 2**-18
    (0xc2781f49ffcfa6d6, 0xc340948e3894da04, 0xaf07f80000000000), // 1e64 * 2**-21
    (0xf316271c7fc3908b, 0x7410b9b1c6ba1085, 0xdac9f60000000000), // 1e65 * 2**-24
    (0x97edd871cfda3a57, 0x688a740f1c344a53, 0xa8be39c000000000), // 1e66 * 2**-28
    (0xbde94e8e43d0c8ed, 0xc2ad1112e3415ce8, 0x92edc83000000000), // 1e67 * 2**-31
    (0xed63a231d4c4fb28, 0xb35855579c11b422, 0xb7a93a3c00000000), // 1e68 * 2**-34
    (0x945e455f24fb1cf9, 0x70173556c18b1095, 0xb2c9c46580000000), // 1e69 * 2**-38
    (0xb975d6b6ee39e437, 0x4c1d02ac71edd4bb, 0x1f7c357ee0000000), // 1e70 * 2**-41
    (0xe7d34c64a9c85d45, 0x9f2443578e6949e9, 0xe75b42de98000000), // 1e71 * 2**-44
    (0x90e40fbeea1d3a4b, 0x4376aa16b901ce32, 0x309909cb1f000000), // 1e72 * 2**-48
    (0xb51d13aea4a488de, 0x9454549c674241be, 0xbcbf4c3de6c00000), // 1e73 * 2**-51
    (0xe264589a4dcdab15, 0x396969c38112d22e, 0x6bef1f4d60700000), // 1e74 * 2**-54
    (0x8d7eb76070a08aed, 0x03e1e21a30abc35d, 0x037573905c460000), // 1e75 * 2**-58
    (0xb0de65388cc8ada9, 0xc4da5aa0bcd6b434, 0x4452d07473578000), // 1e76 * 2**-61
    (0xdd15fe86affad913, 0xb610f148ec0c6141, 0x55678491902d6000), // 1e77 * 2**-64
    (0x8a2dbf142dfcc7ac, 0x91ca96cd9387bcc8, 0xd560b2dafa1c5c00), // 1e78 * 2**-68
    (0xacb92ed9397bf997, 0xb63d3c80f869abfb, 0x0ab8df91b8a37300), // 1e79 * 2**-71
    (0xd7e77a8f87daf7fc, 0x23cc8ba1368416f9, 0xcd67177626cc4fc0), // 1e80 * 2**-74
    (0x86f0ac99b4e8dafe, 0x965fd744c2128e5c, 0x20606ea9d83fb1d8), // 1e81 * 2**-78
    (0xa8acd7c0222311bd, 0x3bf7cd15f29731f3, 0x28788a544e4f9e4e), // 1e82 * 2**-81
    (0xd2d80db02aabd62c, 0x0af5c05b6f3cfe6f, 0xf296ace961e385e1), // 1e83 * 2**-84
    (0x83c7088e1aab65dc, 0x86d9983925861f05, 0xf79e2c11dd2e33ac), // 1e84 * 2**-88
    (0xa4b8cab1a1563f53, 0xa88ffe476ee7a6c7, 0x7585b7165479c098), // 1e85 * 2**-91
    (0xcde6fd5e09abcf27, 0x12b3fdd94aa19079, 0x52e724dbe99830be), // 1e86 * 2**-94
    (0x80b05e5ac60b6179, 0xabb07ea7cea4fa4b, 0xd3d0770971ff1e76), // 1e87 * 2**-98
    (0xa0dc75f1778e39d7, 0x969c9e51c24e38de, 0xc8c494cbce7ee614), // 1e88 * 2**-101
    (0xc913936dd571c84d, 0xfc43c5e632e1c716, 0x7af5b9fec21e9f99), // 1e89 * 2**-104
    (0xfb5878494ace3a60, 0xfb54b75fbf9a38dc, 0x19b3287e72a64780), // 1e90 * 2**-107
    (0x9d174b2dcec0e47c, 0x9d14f29bd7c06389, 0x900ff94f07a7ecb0), // 1e91 * 2**-111
    (0xc45d1df942711d9b, 0xc45a2f42cdb07c6b, 0xf413f7a2c991e7dc), // 1e92 * 2**-114
    (0xf5746577930d6501, 0x3570bb13811c9b86, 0xf118f58b7bf661d3), // 1e93 * 2**-117
    (0x9968bf6abbe85f21, 0x816674ec30b1e134, 0x56af99772d79fd23), // 1e94 * 2**-121
    (0xbfc2ef456ae276e9, 0x61c012273cde5981, 0x6c5b7fd4f8d87c6c), // 1e95 * 2**-124
    (0xefb3ab16c59b14a3, 0x3a3016b10c15efe1, 0xc7725fca370e9b88), // 1e96 * 2**-127
    (0x95d04aee3b80ece6, 0x445e0e2ea78db5ed, 0x1ca77bde62692135), // 1e97 * 2**-131
    (0xbb445da9ca612820, 0xd57591ba51712368, 0x63d15ad5fb036982), // 1e98 * 2**-134
    (0xea1575143cf97227, 0x0ad2f628e5cd6c42, 0x7cc5b18b79c443e3), // 1e99 * 2**-137
    (0x924d692ca61be759, 0xa6c3d9d98fa063a9, 0x8dfb8ef72c1aaa6d), // 1e100 * 2**-141
    (0xb6e0c377cfa2e12f, 0x9074d04ff3887c93, 0xf17a72b4f7215509), // 1e101 * 2**-144
    (0xe498f455c38b997b, 0xf4920463f06a9bb8, 0xedd90f6234e9aa4b), // 1e102 * 2**-147
    (0x8edf98b59a373fed, 0xb8db42be7642a153, 0x94a7a99d61120a6f), // 1e103 * 2**-151
    (0xb2977ee300c50fe8, 0xa712136e13d349a8, 0x79d19404b9568d0b), // 1e104 * 2**-154
    (0xdf3d5e9bc0f653e2, 0xd0d6984998c81c12, 0x9845f905e7ac304d), // 1e105 * 2**-157
    (0x8b865b215899f46d, 0x42861f2dff7d118b, 0x9f2bbba3b0cb9e30), // 1e106 * 2**-161
    (0xae67f1e9aec07188, 0x1327a6f97f5c55ee, 0x86f6aa8c9cfe85bc), // 1e107 * 2**-164
    (0xda01ee641a708dea, 0x17f190b7df336b6a, 0x28b4552fc43e272c), // 1e108 * 2**-167
    (0x884134fe908658b3, 0xcef6fa72eb802322, 0x5970b53ddaa6d87b), // 1e109 * 2**-171
    (0xaa51823e34a7eedf, 0x42b4b90fa6602bea, 0xefcce28d51508e9a), // 1e110 * 2**-174
    (0xd4e5e2cdc1d1ea97, 0x9361e7538ff836e5, 0xabc01b30a5a4b241), // 1e111 * 2**-177
    (0x850fadc09923329f, 0xfc1d309439fb224f, 0x8b5810fe6786ef68), // 1e112 * 2**-181
    (0xa6539930bf6bff46, 0x7b247cb94879eae3, 0x6e2e153e0168ab42), // 1e113 * 2**-184
    (0xcfe87f7cef46ff17, 0x19ed9be79a98659c, 0x49b99a8d81c2d613), // 1e114 * 2**-187
    (0x81f14fae158c5f6f, 0xb0348170c09f3f81, 0xae1400987119c5cc), // 1e115 * 2**-191
    (0xa26da3999aef774a, 0x1c41a1ccf0c70f62, 0x199900be8d60373f), // 1e116 * 2**-194
    (0xcb090c8001ab551d, 0xa3520a402cf8d33a, 0x9fff40ee30b8450f), // 1e117 * 2**-197
    (0xfdcb4fa002162a64, 0x8c268cd038370809, 0x47ff1129bce65652), // 1e118 * 2**-200
    (0x9e9f11c4014dda7f, 0xd798180223226505, 0xccff6aba160ff5f3), // 1e119 * 2**-204
    (0xc646d63501a1511e, 0x4d7e1e02abeafe47, 0x403f45689b93f370), // 1e120 * 2**-207
    (0xf7d88bc24209a566, 0xe0dda58356e5bdd9, 0x104f16c2c278f04c), // 1e121 * 2**-210
    (0x9ae7575969460760, 0xcc8a8772164f96a7, 0xaa316e39b98b9630), // 1e122 * 2**-214
    (0xc1a12d2fc3978938, 0xffad294e9be37c51, 0x94bdc9c827ee7bbc), // 1e123 * 2**-217
    (0xf209787bb47d6b85, 0x3f9873a242dc5b65, 0xf9ed3c3a31ea1aab), // 1e124 * 2**-220
    (0x9745eb4d50ce6333, 0x07bf484569c9b91f, 0xbc3445a45f3250aa), // 1e125 * 2**-224
    (0xbd176620a501fc00, 0x49af1a56c43c2767, 0xab41570d76fee4d5), // 1e126 * 2**-227
    (0xec5d3fa8ce427b00, 0x5c1ae0ec754b3141, 0x9611acd0d4be9e0b), // 1e127 * 2**-230
    (0x93ba47c980e98ce0, 0x3990cc93c94efec8, 0xfdcb0c0284f722c6), // 1e128 * 2**-234
    (0xb8a8d9bbe123f018, 0x47f4ffb8bba2be7b, 0x3d3dcf032634eb78), // 1e129 * 2**-237
    (0xe6d3102ad96cec1e, 0x59f23fa6ea8b6e1a, 0x0c8d42c3efc22656), // 1e130 * 2**-240
    (0x9043ea1ac7e41393, 0x783767c8529724d0, 0x47d849ba75d957f6), // 1e131 * 2**-244
    (0xb454e4a179dd1878, 0xd64541ba673cee04, 0x59ce5c29134fadf3), // 1e132 * 2**-247
    (0xe16a1dc9d8545e95, 0x0bd69229010c2985, 0x7041f33358239970), // 1e133 * 2**-250
    (0x8ce2529e2734bb1e, 0xe7661b59a0a799f3, 0x6629380017163fe6), // 1e134 * 2**-254
    (0xb01ae745b101e9e5, 0xa13fa23008d18070, 0x3fb386001cdbcfe0), // 1e135 * 2**-257
    (0xdc21a1171d42645e, 0x898f8abc0b05e08c, 0x4fa067802412c3d8), // 1e136 * 2**-260
    (0x899504ae72497ebb, 0x95f9b6b586e3ac57, 0xb1c440b0168bba67), // 1e137 * 2**-264
    (0xabfa45da0edbde6a, 0xfb782462e89c976d, 0x9e3550dc1c2ea900), // 1e138 * 2**-267
    (0xd6f8d7509292d604, 0xba562d7ba2c3bd49, 0x05c2a513233a5341), // 1e139 * 2**-270
    (0x865b86925b9bc5c3, 0xf475dc6d45ba564d, 0xa399a72bf6047408), // 1e140 * 2**-274
    (0xa7f26836f282b733, 0x719353889728ebe1, 0x0c8010f6f385910a), // 1e141 * 2**-277
    (0xd1ef0244af236500, 0xcdf8286abcf326d9, 0x4fa01534b066f54d), // 1e142 * 2**-280
    (0x8335616aed761f20, 0x80bb1942b617f847, 0xd1c40d40ee405950), // 1e143 * 2**-284
    (0xa402b9c5a8d3a6e8, 0xa0e9df93639df659, 0xc635109129d06fa4), // 1e144 * 2**-287
    (0xcd036837130890a2, 0xc92457783c8573f0, 0x37c254b574448b8d), // 1e145 * 2**-290
]

@inline(__always)
private func _pm(_ p: Int) -> (high: UInt64, low: UInt64, lowest: UInt64) {
    assert(p >= -149 && p <= 145)
    return _table[unchecked: p &+ 149]
}

private extension UInt64 {
    // Exact division by a constant (cf. Granlund and Montgomery, 1994 §9).
    // Multiply by the inverse of the divisor's odd part (mod `2**64`), then
    // rotate right by the divisor's power-of-two part, to yield the true
    // quotient if and only if division is exact. Every inexact input maps above
    // `UInt64.max / divisor`.
    //
    // One multiply thus serves to compute both divisibility and the quotient.
    @inline(__always)
    func _quotientIfExactDividingBy10() -> Self? {
        let m = 0xCCCCCCCCCCCCCCCD as UInt64 // Inverse of 5 (mod 2**64).
        let p = self &* m
        let q = p &>> 1 | p &<< 63
        guard q <= 1844674407370955161 /* UInt64.max / 10 */ else { return nil }
        return q
    }

    @inline(__always)
    func _quotientIfExactDividingBy100() -> Self? {
        let m = 0x8F5C28F5C28F5C29 as UInt64 // Inverse of 5**2 (mod 2**64).
        let p = self &* m
        let q = p &>> 2 | p &<< 62
        guard q <= 184467440737095516 /* UInt64.max / 100 */ else { return nil }
        return q
    }

    @inline(__always)
    func _quotientIfExactDividingBy10000() -> Self? {
        let m = 0xD288CE703AFB7E91 as UInt64 // Inverse of 5**4 (mod 2**64).
        let p = self &* m
        let q = p &>> 4 | p &<< 60
        guard q <= 1844674407370955 /* UInt64.max / 10**4 */ else { return nil }
        return q
    }

    @inline(__always)
    func _quotientIfExactDividingBy1e8() -> Self? {
        let m = 0xC767074B22E90E21 as UInt64 // Inverse of 5**8 (mod 2**64).
        let p = self &* m
        let q = p &>> 8 | p &<< 56
        guard q <= 184467440737 /* UInt64.max / 10**8 */ else { return nil }
        return q
    }
}

private func _trimZeros(_ x: UInt64, _ p: Int) -> (UInt64, Int) {
    assert(x < 10_0000_0000_0000_0000)
    guard var x = x._quotientIfExactDividingBy10() else {
        return (x, p)
    }
    var p = p &+ 1
    if let q = x._quotientIfExactDividingBy1e8() {
        x = q
        p &+= 8
    }
    if let q = x._quotientIfExactDividingBy10000() {
        x = q
        p &+= 4
    }
    if let q = x._quotientIfExactDividingBy100() {
        x = q
        p &+= 2
    }
    if let q = x._quotientIfExactDividingBy10() {
        x = q
        p &+= 1
    }
    return (x, p)
}

@inline(__always)
private func _pack(normal m: UInt64, _ e: Int) -> Double {
    assert(m & (1 &<< 52) != 0)
    return Double(bitPattern: (m ^ (1 &<< 52)) | (UInt64(e &+ 1075) &<< 52))
}

@inline(__always)
private func _unpack(normal value: Double) -> (m: UInt64, e: Int) {
    assert(value.isNormal)
    return (
        m: (value.significandBitPattern | (1 &<< 52)) &<< 11,
        e: Int(bitPattern: value.exponentBitPattern) &- 1086)
}

// Returns the 'unrounded' result `x * 2**e * 10**p` (that is, with two trailing
// bits for correct rounding), given pre-computed scaling constants `pm` and `s`
// (a 128-bit mantissa, ignoring the lowest 64-bits from the extended table, and
// shift count, respectively).
//
// See Cox's discussion for details and proof of correctness.
@inline(__always)
private func _uscale(
    _ x: UInt64,
    _ pm: (high: UInt64, low: UInt64, lowest: UInt64),
    _ s: Int
) -> UInt64 {
    var hi: UInt64
    let mid: UInt64
    (hi, mid) = x.multipliedFullWidth(by: pm.high)
    var sticky: UInt64 = 1
    if hi & ((1 &<< s) &- 1) == 0 {
        let (mid2, _) = x.multipliedFullWidth(by: pm.low)
        sticky = (mid &- mid2) > 1 ? 1 : 0
        if mid < mid2 { hi &-= 1 }
    }
    return (hi >> s) | sticky
}

// Returns the 'unrounded' result `x * 2**e * 10**p` given pre-computed scaling
// constants `pm` and `s`.
//
// Again, see Cox's discussion for details. This implementation is an extension
// of Cox's unrounded scaler from a 64-bit input and 128-bit table entry to a
// 128-bit input and 192-bit table entry.
//
// We retain Cox's one-multiply guard-bit shortcut. When that shortcut can't be
// taken, we compute the low half of the fix-up product because omitting it has
// been proven for the stronger condition `middle >= 2`, which doesn't hold in
// some cases here at `p == 72` or `p == 73`.
@inline(__always)
private func _uscale128(
    _ x: UInt128,
    _ pm: (high: UInt64, low: UInt64, lowest: UInt64),
    _ s: Int
) -> UInt64 {
    var hi: UInt128
    let mid: UInt128
    (hi, mid) = x.multipliedFullWidth(by: UInt128(pm.high))
    var sticky: UInt64 = 1
    if hi & ((1 &<< s) &- 1) == 0 {
        var mid2: UInt128
        let lo: UInt128
        (mid2, lo) = x.multipliedFullWidth(by: (UInt128(pm.low) &<< 64) | UInt128(pm.lowest))
        if lo != 0 { mid2 &+= 1 }
        sticky = mid != mid2 ? 1 : 0
        if mid < mid2 { hi &-= 1 }
    }
    return UInt64(truncatingIfNeeded: hi >> s) | sticky
}

// Returns the shortest 'formatting' (i.e., decimal representation) of `value`
// that will round-trip back to the original value.
private func _shortest(normal value: Double) -> (d: UInt64, k: Int) {
    assert(value.isNormal)
    let minE = -1085
    let (m, e) = _unpack(normal: value)
    let p: Int
    let lo: UInt64
    if m == 9223372036854775808 /* 1 << 63 */ && e > minE {
        p = -(((e &+ 11) &* 631305 &- 261663) &>> 21)
        lo = m &- 512 // m - (ulp / 4)
    } else {
        // Omit branch for subnormals.
        p = -(((e &+ 11) &* 78913) &>> 18)
        lo = m &- 1024 // m - (ulp / 2)
    }
    let hi = m &+ 1024 // m + (ulp / 2)
    let odd = (m &>> 11) & 1

    let pm = _pm(p)
    let lp = (p &* 108853) &>> 15
    let s = -(e &+ lp &+ 3) // Reserve two extra bits for unrounded representation.
    let dlo = (_uscale(lo, pm, s) &+ odd &+ 3) &>> 2 // Nudge, then take ceiling, shifting out the extra bits.
    let dhi = (_uscale(hi, pm, s) &- odd) &>> 2 // Nudge, then take floor, shifting out the extra bits.

    var d = dhi / 10
    if d &* 10 >= dlo {
        // There's a shorter value with a trailing zero.
        return _trimZeros(d, -(p &- 1))
    }
    d = dlo
    if dlo < dhi {
        // There's more than one candidate of the same length.
        let u = _uscale(m, pm, s)
        d = (u &+ 1 &+ ((u &>> 2) & 1)) &>> 2 // Round (ties to even), shifting out the extra bits.
    }
    return (d, -p)
}

// Returns the `Double` value nearest to the nonzero decimal magnitude
// `d * (10**p)`, with `d` at most `10_000_000_000_000_000_000`.
private func _parse(normal d: UInt64, _ p: Int) -> Double {
    assert(d <= 10_000_000_000_000_000_000)
    let clz = d.leadingZeroBitCount
    let lp = (p &* 108853) &>> 15
    var e = clz &- 11 &- lp // `min(1074, clz &- 11 &- lp)`...
    // ...but `min` is redundant when we limit possible values for `p`.
    assert(e <= 1074)
    var u = _uscale(
        d &<< clz,
        _pm(p),
        8 // `-(e &- clz &+ lp &+ 3)` is a constant when `min` is redundant.
    )
    // Handle the case where the significand would otherwise be 1<<53:
    let s = u >= ((1 &<< 55) &- 2) ? 1 : 0
    u = (u &>> s) | (u & 1)
    e &-= s
    // Round significand (ties to even), shifting out the extra bits.
    return _pack(normal: (u &+ 1 &+ ((u &>> 2) & 1)) &>> 2, -e)
}

// Returns the `Double` value nearest to the nonzero decimal magnitude
// `d * (10**p)`.
//
// This implementation is an extension of Cox's parse for a 128-bit `d` and a
// 192-bit table entry. The additional input bits change `clz - 11 - lp` to
// `clz - 75 - lp`; the scaler shift remains the same constant 8.
private func _parse128(normal d: UInt128, _ p: Int) -> Double {
    assert((-128...127).contains(p))
    let clz = d.leadingZeroBitCount
    let lp = (p &* 108853) &>> 15
    var e = clz &- 75 &- lp
    var u = _uscale128(d &<< clz, _pm(p), 8)
    let s = u >= ((1 &<< 55) &- 2) ? 1 : 0
    u = (u &>> s) | (u & 1)
    e &-= s
    return _pack(normal: (u &+ 1 &+ ((u &>> 2) & 1)) &>> 2, -e)
}

extension Decimal {
    /// Creates a new decimal floating-point value initialized to the given floating-point value.
#if FOUNDATION_FRAMEWORK
    @abi(init(__shortest value: Double))
    @export(implementation)
#endif
    public init(_ value: Double) {
#if FOUNDATION_FRAMEWORK
        guard #available(anyAppleOS 10000, *) else {
            self.init(__legacy: value)
            return
        }
#endif
        self.init(_shortest: value)
    }

#if FOUNDATION_FRAMEWORK
    @available(anyAppleOS 10000, *)
    @usableFromInline
#endif
    internal init(_shortest value: Double) {
        // Note: infinity is represented (as in overflow during arithmetic
        // operations) by NaN, and values that are too small lose precision or
        // flush to zero (as in `init(sign:exponent:significand:)` below).
        let exponent = value.exponent
        // `Decimal.greatestFiniteMagnitude` (gfm) is `(2**128 - 1) * 10**127`,
        // and ⌊ log2(gfm) ⌋ = 549.
        guard exponent <= 549 else {
            // NaN, infinity, or too large.
            self = .nan
            return
        }
        // 5e-129 can round up to 1e-128, and ⌊ log2(5e-129) ⌋ = -427.
        guard exponent >= -427 else {
            // Zero or too small.
            self = Decimal()
            return
        }
        // All subnormal `Double` values have exponent less than -427.
        assert(!value.isSubnormal)
        let (d, k) = _shortest(normal: value.magnitude)
        guard k <= 127 else {
            let shift = k &- 127
            guard shift <= 38 else {
                self = .nan
                return
            }
            let (d_, overflow) =
                UInt128(truncatingIfNeeded: d)
                .multipliedReportingOverflow(by: _uint128_pow10[shift])
            guard !overflow else {
                self = .nan
                return
            }
            self = Decimal()
            self._significand = d_
            self._exponent = 127
            self._isNegative = (value < 0) ? 1 : 0
            self._isCompact = 1
            return
        }
        guard k >= -128 else {
            self = Decimal()
            // Re-round at fixed decimal scale -- cf. Cox's `FixedWidth`.
            let (m, e) = _unpack(normal: value.magnitude)
            let u = _uscale(
                m,
                _pm(128),
                -(e &+ 428)  // `-(e &+ lp &+ 3)`, where `lp = (128 &* 108853) &>> 15`
            )
            let d_ = (u &+ 1 &+ ((u &>> 2) & 1)) &>> 2 // Round (ties to even), shifting out the extra bits.
            if d_ == 0 {
                return
            }
            self._significand = UInt128(truncatingIfNeeded: d_)
            self._exponent = -128
            self._isNegative = (value < 0) ? 1 : 0
            self._isCompact = 0
            self.compact()
            return
        }
        self = Decimal()
        self._significand = UInt128(truncatingIfNeeded: d)
        self._exponent = Int32(truncatingIfNeeded: k)
        self._isNegative = (value < 0) ? 1 : 0
        self._isCompact = 1
    }

    internal var __doubleValue: Double {
        if self._length == 0 {
            return _isNegative == 1 ? .nan : .zero
        }
        let m = _significand
        let p = Int(truncatingIfNeeded: _exponent)
        let abs: Double
        if m <= 10_000_000_000_000_000_000 {
            if m == 0 {
                // This branch is not reachable except with invalid values.
                return _isNegative == 1 ? .nan : .zero
            }
            abs = _parse(normal: UInt64(truncatingIfNeeded: m), p)
        } else {
            abs = _parse128(normal: m, p)
        }
        return _isNegative == 1 ? -abs : abs
    }
}
