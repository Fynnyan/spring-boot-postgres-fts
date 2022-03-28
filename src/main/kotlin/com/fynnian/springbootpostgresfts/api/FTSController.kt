package com.fynnian.springbootpostgresfts.api

import com.beust.klaxon.Klaxon
import com.fynnian.springbootpostgresfts.jooq.enums.Language
import com.fynnian.springbootpostgresfts.repository.CodeRepository
import org.jooq.JSONB
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api")
class FTSController(
    private val codeRepository: CodeRepository
) {

    @GetMapping("/cpv-codes")
    fun getCPVCode(@RequestParam(required = false) parent: String?): List<CPVCode> {
        return codeRepository.getCPVCodes(parent)
    }

    @GetMapping("/cpv-codes/search")
    fun findCPVCode(
        @RequestParam query: String,
        @RequestParam(required = false) language: Language?
    ): List<SearchResult> {
        return codeRepository.findCPVCodes(query, language)
    }
}

data class CPVCode(
    val code: String,
    val label: Localized,
    val hasChildren: Boolean
)

data class Localized(
    val de: String?,
    val fr: String?,
    val it: String?,
    val en: String?
) {
    companion object {
        fun fromJSONB(jsonb: JSONB) = Klaxon().parse<Localized>(jsonb.data())!!
    }
}

data class SearchResult(
    val code: String,
    val name: Localized,
    val parentCode: String?,
    val children: MutableList<SearchResult> = mutableListOf()
)
