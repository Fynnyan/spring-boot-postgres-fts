package com.fynnian.springbootpostgresfts.repository

import com.fynnian.springbootpostgresfts.api.CPVCode
import com.fynnian.springbootpostgresfts.api.Localized
import com.fynnian.springbootpostgresfts.api.SearchResult
import com.fynnian.springbootpostgresfts.jooq.Tables.CPV_CODES
import com.fynnian.springbootpostgresfts.jooq.enums.Language
import org.jooq.DSLContext
import org.jooq.Field
import org.jooq.JSONB
import org.jooq.impl.DSL.*
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional

@Repository
@Transactional
class CodeRepository(
    private val jooq: DSLContext
) {

    fun getCPVCodes(parentCode: String?): List<CPVCode> {

        val codes = CPV_CODES.`as`("codes")
        val children = CPV_CODES.`as`("children")
        val hasChildren: Field<Boolean> =
            `when`(count(children.CODE).ne(0), true).otherwise(false).`as`("has_children")

        return jooq
            .select(codes.asterisk(), hasChildren)
            .from(codes)
            .leftJoin(children).on(children.PARENT_CODE.eq(codes.CODE))
            .let {
                if (parentCode != null) { it.where(codes.PARENT_CODE.eq(parentCode)) }
                else { it.where(codes.PARENT_CODE.isNull) }
            }
            .groupBy(codes.CODE, children.CODE)
            .map { CPVCode(it.get(codes.CODE), Localized.fromJSONB(it.get(codes.NAME)), it.get(hasChildren)) }
    }

    fun findCPVCodes(query: String, language: Language?): List<SearchResult> {

        val lookup = name("lookup")
        val paths = field(lookup.append("paths"))
        val cpv = CPV_CODES.`as`("cpv")

        return jooq.with(
            lookup.`as`(
                select(arrayAgg(CPV_CODES.PATH).`as`(paths))
                    .from(CPV_CODES)
                    .where(fullTextSearchStatement(CPV_CODES.NAME, query, language))
            )
        )
            .selectFrom(cpv)
            // jooq doesn't support the ltree operators jet, write sql with bindings
            .where(field("? @> (select ? from ? )", Boolean::class.java, cpv.PATH, paths, lookup))
            .associateTo(mutableMapOf()) {
                it.code to SearchResult(
                    code = it.code,
                    name = Localized.fromJSONB(it.name),
                    parentCode = it.parentCode
                )
            }
            .buildTree()
    }

    fun fullTextSearchStatement(column: Field<JSONB>, query: String, language: Language?): Field<Boolean> =
        language?.let {
            field(
                "text_to_tsvector( ? ->> ?, ?) @@ localized_websearch_to_tsquery(?, ?)",
                Boolean::class.java,
                column,
                inline(it),
                inline(it),
                query,
                inline(it)
            )
        } ?: field(
            "jsonb_to_tsvector(?) @@ localized_websearch_to_tsquery(?)",
            Boolean::class.java,
            column,
            query
        )
}

private fun MutableMap<String, SearchResult>.buildTree(): List<SearchResult> {
    // build tree from the search result map
    this.values.forEach {
        val parentCode = it.parentCode
        if (this.containsKey(parentCode)) {
            val parent = this[parentCode]!!
            parent.children.add(it)
            this[parent.code] = parent
        }
    }
    // get root nodes, map them and return
    return this.values.filter { it.parentCode == null }
}
